import com.sao.engine.SAOIsoPlayerShell;
import com.sao.engine.SAOMovement;
import com.sao.engine.SAORouteState;
import java.lang.reflect.Field;
import java.util.List;
import zombie.ai.State;
import zombie.ai.StateMachine;
import zombie.ai.astar.AStarPathFinder;
import zombie.ai.states.ClimbOverFenceState;
import zombie.ai.states.ClimbThroughWindowState;
import zombie.characters.IsoPlayer;
import zombie.characters.SurvivorDesc;
import zombie.iso.IsoCell;
import zombie.iso.IsoChunk;
import zombie.iso.IsoChunkMap;
import zombie.iso.IsoDirections;
import zombie.iso.IsoGridSquare;
import zombie.iso.IsoObject;
import zombie.iso.IsoWorld;
import zombie.iso.SpriteDetails.IsoFlagType;
import zombie.iso.sprite.IsoSprite;
import zombie.pathfind.Path;

/** Actual installed shell/state/event/path APIs in a controlled loaded-square fixture. */
public final class MovementCrossingProbe {
    private static int checks;
    private static void check(String name, boolean result) {
        System.out.println("CHECK " + name + "=" + result);
        if (!result) throw new AssertionError(name);
        checks++;
    }
    private static Field field(Class<?> type, String name) throws Exception {
        Field result = type.getDeclaredField(name); result.setAccessible(true); return result;
    }
    private static IsoCell boot() throws Exception {
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
        hair.name = "fixture"; styles.maleStyles.add(hair); styles.femaleStyles.add(hair);
        var beard = new zombie.core.skinnedmodel.population.BeardStyle(); beard.name = "fixture";
        zombie.core.skinnedmodel.population.BeardStyles.instance.styles.add(beard);
        zombie.GameTime.setInstance(new zombie.GameTime());
        zombie.GameTime.getInstance().updateCalendar(1993, 0, 1, 12, 0);
        zombie.characters.skills.PerkFactory.init();
        IsoCell cell = new IsoCell(1, 1);
        zombie.iso.WorldReuserThread.instance.stop();
        IsoWorld.instance.currentCell = cell;
        var map = cell.getChunkMap(0); map.setInitialPos(2, 2); map.ignore = false;
        IsoPlayer.numPlayers = 1;
        for (int wx = 0; wx < 4; wx++) for (int wy = 1; wy < 4; wy++) {
            IsoChunk chunk = new IsoChunk(cell); chunk.wx = wx; chunk.wy = wy; chunk.loaded = true;
            for (int x = 0; x < 8; x++) for (int y = 0; y < 8; y++) {
                IsoGridSquare square = new IsoGridSquare(cell, null, wx * 8 + x, wy * 8 + y, 0);
                square.chunk = chunk; square.getProperties().set(IsoFlagType.solidfloor);
                chunk.setSquare(x, y, 0, square);
            }
            int ix = wx - map.getWorldXMin(), iy = wy - map.getWorldYMin();
            map.getChunks()[iy * IsoChunkMap.chunkGridWidth + ix] = chunk;
        }
        for (int x = 1; x < 31; x++) for (int y = 9; y < 31; y++) {
            var square = cell.getGridSquare(x, y, 0);
            var nav = (IsoGridSquare[]) field(IsoGridSquare.class, "nav").get(square);
            for (IsoDirections dir : IsoDirections.values()) {
                if (dir.ordinal() >= nav.length) continue;
                var delta = dir.ToVector();
                nav[dir.ordinal()] = cell.getGridSquare(x + (int) Math.signum(delta.x), y + (int) Math.signum(delta.y), 0);
            }
        }
        return cell;
    }
    private static SAOIsoPlayerShell person(IsoCell cell) throws Exception {
        var desc = new SurvivorDesc(false); desc.getHumanVisual().setSkinTextureName("fixture");
        var shell = new SAOIsoPlayerShell(cell, desc, 10, 20, 0);
        shell.setECSComponent(new zombie.characters.component.AIComponent());
        var animationConstructor = zombie.core.skinnedmodel.animation.AnimationPlayer.class.getDeclaredConstructor();
        animationConstructor.setAccessible(true);
        field(zombie.characters.IsoGameCharacter.class, "animPlayer").set(shell, animationConstructor.newInstance());
        position(shell, cell, 10.5f, 20.5f);
        state(shell, null); shell.getActionContext().clearActionContextEvents();
        return shell;
    }
    private static void state(SAOIsoPlayerShell shell, State state) throws Exception {
        field(StateMachine.class, "currentState").set(shell.getStateMachine(), state);
    }
    private static void position(SAOIsoPlayerShell shell, IsoCell cell, float x, float y) {
        shell.setX(x); shell.setY(y); shell.setZ(0);
        shell.setCurrent(cell.getGridSquare((int) x, (int) y, 0));
    }
    private static SAORouteState route(float[]... nodes) {
        var state = new SAORouteState(); state.setRoute(List.of(nodes)); state.requested = true;
        return state;
    }
    private static float[] node(float x, float y) { return new float[] { x, y, 0 }; }
    private static String tick(SAOIsoPlayerShell shell, SAORouteState route) {
        try { return SAOMovement.tick(shell, route); }
        catch (Throwable error) { error.printStackTrace(); return "THREW:" + error; }
    }
    private static IsoObject fence(IsoCell cell, int x, int y) {
        var square = cell.getGridSquare(x, y, 0); var fence = new IsoObject(cell);
        fence.setSquare(square); fence.setSprite(new IsoSprite());
        fence.getProperties().set(IsoFlagType.HoppableW);
        square.getObjects().add(fence); square.getProperties().set(IsoFlagType.HoppableW);
        return fence;
    }
    private static void verdict(String name, String expected, String actual) {
        System.out.println("VERDICT " + name + "=" + actual);
        check("native_" + name + "_verdict", expected.equals(actual));
    }
    public static void main(String[] args) throws Exception {
        IsoCell cell = boot();
        for (State crossing : List.of(ClimbOverFenceState.instance(), ClimbThroughWindowState.instance())) {
            var shell = person(cell); var route = route(node(10.5f, 20.5f));
            state(shell, crossing);
            check(crossing.getName() + "_native_flag_false", !shell.isClimbing());
            check(crossing.getName() + "_holds_arrival", tick(shell, route).equals("Transition:CLIMBING")
                && route.requested && route.routeIndex == 0);
            state(shell, null);
            check(crossing.getName() + "_actual_exit_arrives", tick(shell, route).equals("Succeeded") && !route.requested);

            shell = person(cell); state(shell, crossing);
            route = route(node(11.5f, 21.5f));
            cell.getGridSquare(11, 20, 0).getProperties().set(IsoFlagType.WallW);
            cell.getGridSquare(11, 20, 0).getProperties().set(IsoFlagType.collideW);
            check("native_diagonal_is_blocked", shell.getCurrentSquare().isBlockedTo(cell.getGridSquare(11, 21, 0)));
            check(crossing.getName() + "_holds_blocked_diagonal", tick(shell, route).equals("Transition:CLIMBING")
                && route.requested && route.edgeCooldowns.isEmpty());
            state(shell, null);
            String blocked = tick(shell, route);
            check(crossing.getName() + "_exit_keeps_diagonal_block", blocked.equals("FailedObstacle:FAILED_BLOCKED_DIAGONAL"));
            System.out.println("VERDICT blocked_diagonal=" + blocked);
            cell.getGridSquare(11, 20, 0).getProperties().unset(IsoFlagType.WallW);
            cell.getGridSquare(11, 20, 0).getProperties().unset(IsoFlagType.collideW);

            shell = person(cell); state(shell, crossing); route = new SAORouteState(); route.requested = true;
            var nativePath = new Path(); nativePath.addNode(10.5f, 20.5f, 0); nativePath.addNode(12.5f, 20.5f, 0);
            shell.setPath2(nativePath); shell.getFinder().progress = AStarPathFinder.PathFindProgress.found;
            check(crossing.getName() + "_native_route_not_stolen", tick(shell, route).equals("Transition:CLIMBING")
                && route.route.isEmpty() && shell.getPath2() == nativePath);
        }
        for (String event : List.of("EventClimbFence", "EventClimbWindow")) {
            var shell = person(cell); var route = route(node(10.5f, 20.5f));
            shell.getActionContext().reportEvent(event);
            check(event + "_pending_does_not_arrive", tick(shell, route).equals("Transition:CLIMBING") && route.routeIndex == 0);
            check(event + "_pending_is_not_reissued", tick(shell, route).equals("Transition:CLIMBING") && route.routeIndex == 0);
            shell.getActionContext().clearActionContextEvents();
            check(event + "_unentered_request_fails", tick(shell, route).equals("FailedObstacle:FAILED_CROSSING_NOT_ENTERED") && !route.requested);
        }
        var shell = person(cell); var route = route(node(10.5f, 20.5f), node(11.5f, 20.5f), node(13.5f, 20.5f));
        route.advance(); state(shell, ClimbOverFenceState.instance());
        check("overshoot_crossing_owned", tick(shell, route).equals("Transition:CLIMBING"));
        position(shell, cell, 12.1f, 20.5f); state(shell, null);
        check("native_exit_projects_forward", tick(shell, route).equals("ManualRoute") && route.routeIndex == 2 && shell.playerMoveDir.x > 0);

        shell = person(cell); route = route(node(10.5f, 20.5f), node(11.5f, 20.5f), node(12.5f, 20.5f));
        route.advance(); state(shell, ClimbThroughWindowState.instance()); tick(shell, route);
        position(shell, cell, 10.9f, 21.5f); state(shell, null);
        int matrix = shell.getCurrentSquare().collideMatrix;
        shell.getCurrentSquare().collideMatrix = -1;
        check("native_projection_collision_present", shell.getCurrentSquare().testCollideAdjacent(shell, 0, -1, 0));
        check("native_projection_collision_not_skipped", tick(shell, route).equals("FailedObstacle:FAILED_CROSSING_ROUTE_RECONCILIATION"));
        shell.getCurrentSquare().collideMatrix = matrix;

        shell = person(cell); var wall = fence(cell, 11, 20); route = route(node(11.5f, 20.5f));
        check("native_fixture_fence_detected", shell.getCurrentSquare().getWallHoppableTo(cell.getGridSquare(11, 20, 0)) == wall);
        String accepted = tick(shell, route); System.out.println("ADMISSION " + accepted);
        check("native_fence_request_acknowledged", accepted.equals("Transition:STARTED_FENCE_CLIMB")
            && shell.getActionContext().hasEventOccurred("EventClimbFence") && !shell.isClimbing());
        check("native_fence_pending_retains_route", tick(shell, route).equals("Transition:CLIMBING") && route.requested && route.routeIndex == 0);
        shell.getActionContext().clearActionContextEvents(); state(shell, ClimbOverFenceState.instance());
        check("native_fence_pending_enters_state", tick(shell, route).equals("Transition:CLIMBING") && route.requested);
        position(shell, cell, 11.7f, 20.5f); state(shell, null);
        check("native_fence_entered_state_finishes", tick(shell, route).equals("Succeeded"));

        shell = person(cell); position(shell, cell, 10.75f, 20.5f);
        route = new SAORouteState(); route.requested = true;
        var behavior = shell.getPathFindBehavior2(); behavior.pathToLocationF(12.5f, 20.5f, 0);
        var generated = new Path(); generated.addNode(10.75f, 20.5f, 0); generated.addNode(12.5f, 20.5f, 0);
        behavior.Succeeded(generated, shell);
        String nativeUpdate = tick(shell, route); System.out.println("NATIVE_UPDATE " + nativeUpdate);
        check("native_update_pending_route_not_captured", nativeUpdate.equals("Transition:CLIMBING")
            && shell.getActionContext().hasEventOccurred("EventClimbFence") && route.route.isEmpty() && shell.getPath2() != null);

        shell = person(cell); route = route(node(11.5f, 20.5f));
        // The source square exists, but native adjacency is unavailable. The
        // real void climbOverFence call silently refuses this incomplete edge.
        var nav = (IsoGridSquare[]) field(IsoGridSquare.class, "nav").get(shell.getCurrentSquare());
        var next = nav[IsoDirections.E.ordinal()]; nav[IsoDirections.E.ordinal()] = null;
        String refused = tick(shell, route); System.out.println("REFUSAL " + refused);
        check("native_fence_refusal_not_started", refused.equals("FailedObstacle:FAILED_FENCE_CLIMB_REFUSED")
            && !shell.getActionContext().hasEventOccurred("EventClimbFence") && !route.requested);
        nav[IsoDirections.E.ordinal()] = next;

        cell.getGridSquare(11, 20, 0).getObjects().remove(wall);
        cell.getGridSquare(11, 20, 0).getProperties().unset(IsoFlagType.HoppableW);
        var window = new zombie.iso.objects.IsoWindow(cell);
        window.setSquare(cell.getGridSquare(11, 20, 0)); window.setSprite(new IsoSprite());
        field(zombie.iso.objects.IsoWindow.class, "open").setBoolean(window, true);
        window.getSquare().getObjects().add(window); window.getSquare().getSpecialObjects().add(window);
        shell = person(cell); route = route(node(11.5f, 20.5f));
        check("native_window_fixture_climbable", window.canClimbThrough(shell)
            && shell.getCurrentSquare().getWindowTo(window.getSquare()) == window);
        String windowRequest = tick(shell, route); System.out.println("WINDOW " + windowRequest);
        check("native_window_request_acknowledged", windowRequest.equals("Transition:STARTED_WINDOW_CLIMB")
            && shell.getActionContext().hasEventOccurred("EventClimbWindow") && !shell.isClimbing());
        check("native_window_pending_retains_route", tick(shell, route).equals("Transition:CLIMBING") && route.routeIndex == 0);
        shell.getActionContext().clearActionContextEvents(); route.clearRoute(); route.setRoute(List.of(node(10.5f, 20.5f)));
        check("cleared_route_does_not_inherit_pending", tick(shell, route).equals("Succeeded"));

        // Native world-object verdicts are also fed through the real Lua
        // Locomotion/Controller boundary by Border 82. No verdict is mocked here.
        shell = person(cell); route = route(node(11.5f, 20.5f));
        field(zombie.iso.objects.IsoWindow.class, "open").setBoolean(window, false);
        route.interactionStage = "OPEN_ATTEMPTED";
        verdict("window_declined", "FailedObstacle:FAILED_WINDOW_DECLINED", tick(shell, route));
        var barricade = new zombie.iso.objects.IsoBarricade(window.getSquare(), IsoDirections.W);
        barricade.addPlank(null);
        window.getSquare().getObjects().add(barricade);
        window.getSquare().getSpecialObjects().add(barricade);
        check("native_window_barricade_present", window.isBarricaded() && barricade.getNumPlanks() == 1);
        verdict("barricaded_window", "FailedObstacle:FAILED_BARRICADED_WINDOW",
            tick(person(cell), route(node(11.5f, 20.5f))));
        window.getSquare().getObjects().remove(barricade);
        window.getSquare().getSpecialObjects().remove(barricade);
        window.getSquare().getObjects().remove(window);
        window.getSquare().getSpecialObjects().remove(window);

        var door = new zombie.iso.objects.IsoDoor(cell);
        door.setSquare(cell.getGridSquare(11, 20, 0)); door.setSprite(new IsoSprite());
        door.setKeyId(1729); door.setLockedByKey(true);
        door.getSquare().getObjects().add(door); door.getSquare().getSpecialObjects().add(door);
        shell = person(cell); shell.getCurrentSquare().getProperties().set(IsoFlagType.exterior);
        check("native_locked_door_present", door.isLockedByKey() && !door.IsOpen()
            && shell.getCurrentSquare().getDoorTo(door.getSquare()) == door);
        verdict("locked_door", "FailedObstacle:FAILED_LOCKED_DOOR", tick(shell, route(node(11.5f, 20.5f))));
        door.getSquare().getObjects().add(barricade); door.getSquare().getSpecialObjects().add(barricade);
        check("native_door_barricade_present", door.isBarricaded());
        verdict("barricaded_door", "FailedObstacle:FAILED_BARRICADED_DOOR",
            tick(person(cell), route(node(11.5f, 20.5f))));
        System.out.println("PASS movement crossing checks=" + checks);
    }
}
