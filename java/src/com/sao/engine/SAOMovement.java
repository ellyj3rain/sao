package com.sao.engine;

import com.sao.agent.SAOAgent;
import java.util.ArrayList;
import java.util.List;
import zombie.characters.IsoPlayer;
import zombie.characters.component.AIComponent;
import zombie.iso.IsoCell;
import zombie.iso.IsoGridSquare;
import zombie.iso.IsoObject;
import zombie.iso.objects.IsoDoor;
import zombie.iso.objects.IsoWindow;
import zombie.pathfind.Path;
import zombie.pathfind.PathFindBehavior2;

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
        PathFindBehavior2 behavior = shell.getPathFindBehavior2();
        PathFindBehavior2.BehaviorResult result = behavior.update();
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
        if (shell.isClimbing()) {
            return "CLIMBING";
        }
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
            return "STARTED_WINDOW_CLIMB";
        }
        return "CLEAR";
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

        float animAngle = shell.getAnimAngleRadians();
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
