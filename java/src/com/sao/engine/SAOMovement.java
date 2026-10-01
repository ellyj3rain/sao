package com.sao.engine;

import com.sao.agent.SAOAgent;
import java.lang.reflect.Field;
import java.util.ArrayList;
import java.util.List;
import zombie.characters.IsoPlayer;
import zombie.characters.component.AIComponent;
import zombie.iso.IsoCell;
import zombie.iso.IsoDirections;
import zombie.iso.IsoGridSquare;
import zombie.iso.IsoObject;
import zombie.inventory.InventoryItem;
import zombie.inventory.types.HandWeapon;
import zombie.iso.objects.IsoDoor;
import zombie.iso.objects.IsoWindow;
import zombie.pathfind.Path;
import zombie.pathfind.PathFindBehavior2;
import zombie.ai.states.ClimbOverFenceState;
import zombie.ai.states.ClimbThroughWindowState;

/**
 * The movement loop, transplanted faithfully from the reference implementation
 * (KnoxNpcFactory.moveTo / tickMovement / captureEngineRoute /
 * driveCapturedRoute / handleRouteTransition / applyHumanMovementIntent /
 * clearHumanMovementIntent) as direct-typed Java. Nothing in the hot path is
 * reachable from Lua by design: every walk failure across sao-5..sao-9 was Lua
 * touching engine objects Kahlua cannot handle.
 *
 * Verdicts are one-line strings, the reference's own discipline.
 */
public final class SAOMovement {

    private static final float NODE_ADVANCE_DISTANCE = 0.35f;
    // A horse's collision footprint and rider anchor settle farther from a
    // human-centered path node. Mounted routing owns a wider node radius so a
    // horse that has physically reached the node continues along the route.
    private static final float MOUNTED_NODE_ADVANCE_DISTANCE = 1.0f;

    private SAOMovement() {
    }

    /** Request a route to a tile. The body-level call arms character pathfinding. */
    public static String begin(SAOIsoPlayerShell shell, SAORouteState state, int x, int y, int z) {
        return begin(shell, state, x, y, z, false);
    }

    public static String begin(
        SAOIsoPlayerShell shell, SAORouteState state, int x, int y, int z, boolean running) {
        state.clearRoute();
        state.requested = true;
        state.running = running;
        state.targetX = x + 0.5f;
        state.targetY = y + 0.5f;
        state.targetZ = z;
        shell.pathToLocationF(x + 0.5f, y + 0.5f, z);
        return "MOVE_STARTED target=" + x + "," + y + "," + z;
    }

    /**
     * One tick. Returns the reference's states: Working / ManualRoute /
     * Succeeded / Failed* / transition names.
     */
    public static String tick(SAOIsoPlayerShell shell, SAORouteState state) {
        if (!state.requested) {
            return "IDLE";
        }
        if (state.hasRoute()) {
            String result = driveCapturedRoute(shell, state);
            if ("Succeeded".equals(result) || result.startsWith("Failed")) {
                state.requested = false;
            }
            return result;
        }
        String crossing = yieldCrossing(shell, state);
        if (crossing != null) return crossing;
        PathFindBehavior2 behavior = shell.getPathFindBehavior2();
        PathFindBehavior2.BehaviorResult result = behavior.update();
        // update() can itself report a climb event before entering its state.
        // Capturing/cancelling that native behavior here would steal its crossing.
        crossing = yieldCrossing(shell, state);
        if (crossing != null) return crossing;
        if (result == PathFindBehavior2.BehaviorResult.Working) {
            if (captureEngineRoute(shell, state, behavior)) {
                return driveCapturedRoute(shell, state);
            }
            clearIntent(shell);
            return "Working";
        }
        clearIntent(shell);
        state.requested = false;
        return result.name();
    }

    public static String cancel(SAOIsoPlayerShell shell, SAORouteState state) {
        shell.getPathFindBehavior2().cancel();
        shell.setPath2(null);
        state.clearRoute();
        state.requested = false;
        clearIntent(shell);
        return "MOVE_CANCELLED";
    }

    /**
     * Advance native path computation without applying human foot movement and
     * expose the current route node to another owned locomotion body. Mounted
     * travel uses this to steer the horse through the route the engine found;
     * the horse system still owns collision, stamina, animation and position.
     */
    public static String waypoint(SAOIsoPlayerShell shell, SAORouteState state) {
        if (!state.requested) return "IDLE";
        if (!state.hasRoute()) {
            PathFindBehavior2 behavior = shell.getPathFindBehavior2();
            PathFindBehavior2.BehaviorResult result = behavior.update();
            if (result == PathFindBehavior2.BehaviorResult.Working) {
                if (!captureEngineRoute(shell, state, behavior)) return "ROUTE_WORKING";
            } else {
                state.requested = false;
                return "ROUTE_" + result.name();
            }
        }
        float x = shell.getX(), y = shell.getY();
        float[] node = state.currentNode();
        while (node != null && distance(x, y, node[0], node[1]) <= MOUNTED_NODE_ADVANCE_DISTANCE
                && Math.abs(shell.getZ() - node[2]) < 0.8f) {
            state.advance();
            node = state.currentNode();
        }
        if (node == null) {
            state.requested = false;
            return "ROUTE_SUCCEEDED";
        }
        return "WAYPOINT@" + node[0] + "@" + node[1] + "@" + node[2];
    }

    // ------------------------------------------------------------------
    // Faithful ports
    // ------------------------------------------------------------------

    /** KNF.captureEngineRoute: read path2 nodes, then dismiss the behavior. */
    private static boolean captureEngineRoute(
        SAOIsoPlayerShell shell, SAORouteState state, PathFindBehavior2 behavior) {
        Path path = shell.getPath2();
        if (path == null) {
            return false;
        }
        int size = path.size();
        if (size <= 0) {
            return false;
        }
        List<float[]> nodes = new ArrayList<>(size);
        for (int index = 0; index < size; index++) {
            var node = path.getNode(index);
            nodes.add(new float[] { node.x, node.y, node.z });
        }
        behavior.cancel();
        shell.setPath2(null);
        state.setRoute(nodes);
        SAOAgent.log("route captured: " + size + " nodes");
        return true;
    }

    /** KNF.driveCapturedRoute: advance nodes, gate transitions, drive intent. */
    private static String driveCapturedRoute(SAOIsoPlayerShell shell, SAORouteState state) {
        String crossing = yieldCrossing(shell, state);
        if (crossing != null) return crossing;
        if (state.realignAfterCrossing && !realignAfterCrossing(shell, state)) {
            clearIntent(shell);
            return "FailedObstacle:FAILED_CROSSING_ROUTE_RECONCILIATION";
        }
        float x = shell.getX();
        float y = shell.getY();

        float[] node = state.currentNode();
        while (node != null && distance(x, y, node[0], node[1]) <= NODE_ADVANCE_DISTANCE
            && Math.abs(shell.getZ() - node[2]) < 0.8f) {
            state.advance();
            node = state.currentNode();
        }
        if (node == null) {
            clearIntent(shell);
            return "Succeeded";
        }

        String transition = handleRouteTransition(shell, state, node);
        if (transition.startsWith("FAILED_")) {
            // A terminal observation keeps the exact native waypoint and body
            // position, so a failed diagonal can be distinguished from a bad
            // captured route without logging every movement tick.
            SAOAgent.log("route failed person=" + shell.getModData().rawget("SAOPersonId")
                + " result=" + transition + " at=" + x + "," + y + "," + shell.getZ()
                + " node=" + node[0] + "," + node[1] + "," + node[2]
                + " index=" + state.routeIndex + "/" + state.route.size()
                + " goal=" + state.targetX + "," + state.targetY + "," + state.targetZ);
            IsoGridSquare current = shell.getCurrentSquare();
            if (current != null) {
                state.rememberEdgeFailure(
                    edgeKey(current, node), transition);
            }
            clearIntent(shell);
            return "FailedObstacle:" + transition;
        }
        if (!"CLEAR".equals(transition)) {
            clearIntent(shell);
            return "Transition:" + transition;
        }

        drive(shell, node[0], node[1], state.running);
        return "ManualRoute";
    }

    private static boolean nativeCrossing(SAOIsoPlayerShell shell) {
        // isClimbing() covers ropes in this engine; fence/window states never
        // set that flag. Match the same native states PathFindBehavior2 yields to.
        return shell.isClimbing()
            || shell.getCurrentState() == ClimbOverFenceState.instance()
            || shell.getCurrentState() == ClimbThroughWindowState.instance();
    }

    /** A native event acknowledges a request, not completion or state entry. */
    private static String crossingTransition(SAOIsoPlayerShell shell, SAORouteState state) {
        if (nativeCrossing(shell)) {
            state.crossingObserved = true;
            state.pendingCrossingEvent = null;
            return "CLIMBING";
        }
        if (state.crossingObserved) {
            state.crossingObserved = false;
            state.pendingCrossingEvent = null;
            state.realignAfterCrossing = true;
            return null;
        }
        if (state.pendingCrossingEvent != null) {
            if (shell.getActionContext().hasEventOccurred(state.pendingCrossingEvent)) return "CLIMBING";
            state.pendingCrossingEvent = null;
            return "FAILED_CROSSING_NOT_ENTERED";
        }
        for (String event : new String[] { "EventClimbFence", "EventClimbWindow" }) {
            if (shell.getActionContext().hasEventOccurred(event)) {
                state.pendingCrossingEvent = event;
                return "CLIMBING";
            }
        }
        return null;
    }

    private static String yieldCrossing(SAOIsoPlayerShell shell, SAORouteState state) {
        String transition = crossingTransition(shell, state);
        if (transition == null) return null;
        clearIntent(shell);
        if (transition.startsWith("FAILED_")) {
            state.requested = false;
            return "FailedObstacle:" + transition;
        }
        return "Transition:" + transition;
    }

    private static String admittedCrossing(SAOIsoPlayerShell shell, SAORouteState state,
            String event, String accepted, String refused) {
        if (nativeCrossing(shell)) {
            state.crossingObserved = true;
            state.pendingCrossingEvent = null;
            return accepted;
        }
        if (shell.getActionContext().hasEventOccurred(event)) {
            state.pendingCrossingEvent = event;
            return accepted;
        }
        return refused;
    }

    private static final class NativeRoutePoint {
        // The installed helper is public; its result fields are package-private.
        // Read its actual projection instead of inventing a nearest-node rule.
        static final Field INDEX = field("pathIndex"), X = field("x"), Y = field("y");
        private static Field field(String name) {
            try {
                Field field = PathFindBehavior2.PointOnPath.class.getDeclaredField(name);
                field.setAccessible(true);
                return field;
            } catch (ReflectiveOperationException failure) {
                throw new IllegalStateException("Native path projection unavailable", failure);
            }
        }
    }

    private static boolean realignAfterCrossing(SAOIsoPlayerShell shell, SAORouteState state) {
        if (state.route.size() > 1) {
            int first = Math.max(0, state.routeIndex - 1);
            Path path = new Path();
            for (int i = first; i < state.route.size(); i++) {
                float[] node = state.route.get(i);
                path.addNode(node[0], node[1], node[2]);
            }
            PathFindBehavior2.PointOnPath point = new PathFindBehavior2.PointOnPath();
            try {
                NativeRoutePoint.X.setFloat(point, Float.NaN);
                NativeRoutePoint.Y.setFloat(point, Float.NaN);
                // This native projection checks adjacent collisions, floors and
                // apparent stair height before choosing the forward segment.
                PathFindBehavior2.closestPointOnPath(shell.getX(), shell.getY(), shell.getZ(), shell, path, point);
                if (!Float.isFinite(NativeRoutePoint.X.getFloat(point))
                        || !Float.isFinite(NativeRoutePoint.Y.getFloat(point))) return false;
                int next = first + NativeRoutePoint.INDEX.getInt(point) + 1;
                while (state.routeIndex < next) state.advance();
            } catch (ReflectiveOperationException failure) {
                throw new IllegalStateException("Native path projection unreadable", failure);
            }
        }
        state.realignAfterCrossing = false;
        return true;
    }

    /** Whether the step between floors crosses stair geometry: stairs on
     * the current square, on the next column at either floor, or a
     * stairs-below marker on either side of the seam. */
    private static boolean stairSeam(
        IsoCell cell, IsoGridSquare current, int nextX, int nextY) {
        try {
            if (current.HasStairs() || current.HasStairsBelow()) {
                return true;
            }
            IsoGridSquare sameFloor = cell.getGridSquare(nextX, nextY, current.getZ());
            if (sameFloor != null && (sameFloor.HasStairs() || sameFloor.HasStairsBelow())) {
                return true;
            }
            IsoGridSquare above = cell.getGridSquare(nextX, nextY, current.getZ() + 1);
            if (above != null && above.HasStairsBelow()) {
                return true;
            }
            IsoGridSquare below = cell.getGridSquare(nextX, nextY, current.getZ() - 1);
            return below != null && below.HasStairs();
        } catch (Throwable throwable) {
            return false;
        }
    }

    /** KNF.handleRouteTransition: doors, diagonals, cooldowns, windows, and
     * stair-seam Z steps (walked, like the engine walks them). Z changes
     * without stair geometry stay loud failures rather than silent stalls. */
    private static String handleRouteTransition(
        SAOIsoPlayerShell shell, SAORouteState state, float[] node) {
        String crossing = crossingTransition(shell, state);
        if (crossing != null) return crossing;
        IsoGridSquare current = shell.getCurrentSquare();
        IsoCell cell = shell.getCell();
        if (current == null || cell == null) {
            return "FAILED_NO_CURRENT_SQUARE";
        }
        int currentX = current.getX();
        int currentY = current.getY();
        int currentZ = current.getZ();
        int nextX = (int) Math.floor(node[0]);
        int nextY = (int) Math.floor(node[1]);
        int nextZ = (int) Math.floor(node[2]);
        int deltaX = nextX - currentX;
        int deltaY = nextY - currentY;

        if (deltaX == 0 && deltaY == 0 && nextZ == currentZ) {
            return "CLEAR";
        }
        if (nextZ != currentZ) {
            if (Math.abs(nextZ - currentZ) == 1 && stairSeam(cell, current, nextX, nextY)) {
                return "CLEAR";
            }
            return "FAILED_UNSUPPORTED_Z_CHANGE";
        }
        if (Math.abs(deltaX) > 1 || Math.abs(deltaY) > 1) {
            return "CLEAR";
        }
        IsoGridSquare next = cell.getGridSquare(nextX, nextY, nextZ);
        if (next == null) {
            return "FAILED_UNLOADED_NEXT_SQUARE";
        }
        if (Math.abs(deltaX) + Math.abs(deltaY) != 1) {
            return current.isBlockedTo(next) ? "FAILED_BLOCKED_DIAGONAL" : "CLEAR";
        }
        if (state.edgeCooling(edgeKey(current, node))) {
            return "FAILED_EDGE_COOLDOWN";
        }

        IsoObject doorObject = current.getDoorTo(next);
        if (doorObject instanceof IsoDoor door) {
            if (door.IsOpen()) {
                return "CLEAR";
            }
            if (door.isBarricaded()) {
                return "FAILED_BARRICADED_DOOR";
            }
            shell.faceThisObject(door);
            if (shell.shouldBeTurning()) {
                return "TURNING_TO_DOOR";
            }
            door.ToggleDoor(shell);
            return door.IsOpen() ? "OPENING_DOOR" : "FAILED_LOCKED_DOOR";
        }

        // [C4] The hoppable edge. The engine's own paths cross low
        // fences; the drive walked into them forever and the job died
        // at the stall counter with no name ("stalled:ManualRoute" was
        // the whole verdict). The square knows its edges exactly - ask
        // it the way the neighbour framework taught us to ask, face
        // the crossing, and climb through the engine's own state.
        IsoObject hoppable = current.getHoppableTo(next);
        if (hoppable == null) {
            hoppable = current.getWallHoppableTo(next);
        }
        if (hoppable != null) {
            shell.faceLocationF(nextX + 0.5f, nextY + 0.5f);
            if (shell.shouldBeTurning()) {
                return "TURNING_TO_FENCE";
            }
            shell.climbOverFence(cardinal(deltaX, deltaY));
            return admittedCrossing(shell, state, "EventClimbFence",
                "STARTED_FENCE_CLIMB", "FAILED_FENCE_CLIMB_REFUSED");
        }

        IsoWindow window = current.getWindowTo(next);
        if (window != null) {
            if (window.isBarricaded()) {
                return "FAILED_BARRICADED_WINDOW";
            }
            String characterState = String.valueOf(shell.getCurrentStateName());
            if (characterState.contains("OpenWindowState")) {
                String completion = String.valueOf(
                    shell.getVariableString("StopAfterAnimLooped"));
                if ("success".equalsIgnoreCase(completion) && !window.IsOpen()) {
                    // OpenWindowState only toggles the world object for a
                    // local player; complete that omitted step manually.
                    window.ToggleWindow(shell);
                    if (!window.IsOpen()) {
                        return "FAILED_WINDOW_OPEN_COMPLETION";
                    }
                    state.interactionStage = "OPEN_COMPLETED";
                    return "COMPLETED_WINDOW_OPEN";
                }
                return "OPENING_WINDOW";
            }
            if (characterState.contains("SmashWindowState")) {
                return "SMASHING_WINDOW";
            }

            boolean open = window.IsOpen();
            boolean smashed = window.isSmashed();
            shell.faceThisObject(window);
            if (shell.shouldBeTurning()) {
                return "TURNING_TO_WINDOW";
            }
            if (!open && !smashed) {
                if ("NONE".equals(state.interactionStage)) {
                    shell.openWindow(window);
                    state.interactionStage = "OPEN_ATTEMPTED";
                    return "STARTED_WINDOW_OPEN";
                }
                if ("OPEN_ATTEMPTED".equals(state.interactionStage)) {
                    // The smash is a DECISION the composition made upstream
                    // (urgency or standing hostility), never a reflex. Without
                    // permission the survivor declines - the window-smash case
                    // from CORE.md, enforced at the execution layer.
                    if (!state.mayForceEntry) {
                        return "FAILED_WINDOW_DECLINED";
                    }
                    shell.smashWindow(window);
                    state.interactionStage = "SMASH_ATTEMPTED";
                    return "STARTED_WINDOW_SMASH";
                }
                return "FAILED_WINDOW_SMASH_DID_NOT_BREAK";
            }
            if (!window.canClimbThrough(shell)) {
                return "FAILED_BLOCKED_WINDOW";
            }
            shell.climbThroughWindow(window);
            return admittedCrossing(shell, state, "EventClimbWindow",
                "STARTED_WINDOW_CLIMB", "FAILED_WINDOW_CLIMB_REFUSED");
        }
        return "CLEAR";
    }

    private static IsoDirections cardinal(int deltaX, int deltaY) {
        if (deltaX == 1) return IsoDirections.E;
        if (deltaX == -1) return IsoDirections.W;
        if (deltaY == 1) return IsoDirections.S;
        return IsoDirections.N;
    }

    /** [C118] The batter: one engine-true hit with the held weapon on
     * the locked or barricaded barrier between the shell and the
     * direction it was walking, through the engine's own WeaponHit -
     * the same price a player pays: barricade planks by the engine's
     * own damage math, door health down, and the thump noise of it
     * drawing whatever hears it. Never a decision: the composition
     * decides who batters (Disposition) and whether the ground beyond
     * was theirs to enter (Standing); this only swings. The edge
     * toward the goal is asked first, then every cardinal edge of the
     * square the shell stands on. An empty hand is an honest limit -
     * fists do not batter, and the walk gives up wanting the door. */
    public static String batter(SAOIsoPlayerShell shell, int towardX, int towardY) {
        try {
            InventoryItem held = shell.getPrimaryHandItem();
            if (!(held instanceof HandWeapon weapon)) {
                return "UNARMED";
            }
            IsoCell cell = shell.getCell();
            int cx = (int) shell.getX();
            int cy = (int) shell.getY();
            int cz = (int) shell.getZ();
            IsoGridSquare here = cell.getGridSquare(cx, cy, cz);
            if (here == null) {
                return "NOTHING_TO_BATTER";
            }
            int signX = Integer.signum(towardX - cx);
            int signY = Integer.signum(towardY - cy);
            int[][] edges = {
                {signX, 0}, {0, signY},
                {1, 0}, {-1, 0}, {0, 1}, {0, -1}
            };
            for (int i = 0; i < edges.length; i++) {
                int dx = edges[i][0];
                int dy = edges[i][1];
                if (dx == 0 && dy == 0) {
                    continue;
                }
                IsoGridSquare next = cell.getGridSquare(cx + dx, cy + dy, cz);
                if (next == null) {
                    continue;
                }
                IsoObject doorObject = here.getDoorTo(next);
                if (doorObject instanceof IsoDoor door) {
                    if (door.isBarricaded() || (door.isLocked() && !door.IsOpen())) {
                        shell.faceThisObject(door);
                        door.WeaponHit(shell, weapon);
                        if (door.isDestroyed()) {
                            return "DOOR_DOWN";
                        }
                        return "DOOR";
                    }
                }
                IsoWindow window = here.getWindowTo(next);
                if (window != null && window.isBarricaded()) {
                    shell.faceThisObject(window);
                    window.WeaponHit(shell, weapon);
                    return "WINDOW";
                }
            }
            return "NOTHING_TO_BATTER";
        } catch (Throwable throwable) {
            SAOAgent.log("batter threw: " + throwable);
            return "BATTER_FAILED";
        }
    }

    /** [C4] Follow recovery. When the pathfinder has no route to a
     * close same-floor target - the player went through a window or
     * over a fence, and the polygon map does not route a shell after
     * them - interact with the one edge between here and there,
     * through the same transition logic a captured route uses, on a
     * synthesized single step toward the target. Never a smash: the
     * follow keeps mayForceEntry wherever the composition left it. */
    public static String traverseToward(
        SAOIsoPlayerShell shell, SAORouteState state, int tx, int ty) {
        String crossing = crossingTransition(shell, state);
        if (crossing != null) return crossing;
        IsoGridSquare current = shell.getCurrentSquare();
        if (current == null) {
            return "FAILED_NO_CURRENT_SQUARE";
        }
        int stepX = Integer.compare(tx, current.getX());
        int stepY = Integer.compare(ty, current.getY());
        if (stepX == 0 && stepY == 0) {
            return "CLEAR";
        }
        int nextX = current.getX();
        int nextY = current.getY();
        if (Math.abs(tx - current.getX()) >= Math.abs(ty - current.getY())) {
            nextX += stepX;
        } else {
            nextY += stepY;
        }
        float[] node = { nextX + 0.5f, nextY + 0.5f, current.getZ() };
        return handleRouteTransition(shell, state, node);
    }

    /** KNF.applyHumanMovementIntent, walk pace: body-level intent plus the
     * world-to-animation control-space strafe conversion. */
    static void drive(SAOIsoPlayerShell shell, float nextX, float nextY, boolean running) {
        float x = shell.getX();
        float y = shell.getY();
        float deltaX = nextX - x;
        float deltaY = nextY - y;
        float length = (float) Math.sqrt(deltaX * deltaX + deltaY * deltaY);
        if (length <= 0.001f) {
            clearIntent(shell);
            return;
        }
        float dirX = deltaX / length;
        float dirY = deltaY / length;

        shell.playerMoveDir.x = dirX;
        shell.playerMoveDir.y = dirY;
        shell.setJustMoved(true);
        shell.setDirectionAngle((float) Math.toDegrees(Math.atan2(dirY, dirX)));
        shell.setRunning(running);

        // Native IsoPlayer input uses AnimationPlayer.getRenderedAngle(),
        // whose basis is getAngle() + PI/2. AI strafe values are consumed
        // directly as DeltaX/DeltaY, so they need that same basis.
        float animAngle = shell.getAnimAngleRadians() + (float) (Math.PI / 2);
        float controlX = dirX;
        float controlY = -dirY;
        float cos = (float) Math.cos(animAngle);
        float sin = (float) Math.sin(animAngle);
        AIComponent ai = shell.getECSComponent(AIComponent.class);
        if (ai != null) {
            var vars = ai.getHumanControlVars();
            if (vars != null) {
                vars.justMoved = true;
                vars.running = running;
                vars.strafeX = controlX * cos - controlY * sin;
                vars.strafeY = controlX * sin + controlY * cos;
            }
        }
    }

    /** KNF.clearHumanMovementIntent. */
    static void clearIntent(SAOIsoPlayerShell shell) {
        shell.playerMoveDir.x = 0.0f;
        shell.playerMoveDir.y = 0.0f;
        shell.setJustMoved(false);
        shell.setRunning(false);
        shell.setSprinting(false);
        shell.setSneaking(false);
        AIComponent ai = shell.getECSComponent(AIComponent.class);
        if (ai != null) {
            var vars = ai.getHumanControlVars();
            if (vars != null) {
                vars.justMoved = false;
                vars.running = false;
                vars.strafeX = 0.0f;
                vars.strafeY = 0.0f;
            }
        }
    }

    private static String edgeKey(IsoGridSquare current, float[] node) {
        return current.getX() + "," + current.getY() + "," + current.getZ()
            + ">" + (int) Math.floor(node[0]) + "," + (int) Math.floor(node[1])
            + "," + (int) Math.floor(node[2]);
    }

    private static float distance(float ax, float ay, float bx, float by) {
        float dx = ax - bx;
        float dy = ay - by;
        return (float) Math.sqrt(dx * dx + dy * dy);
    }
}
