package com.sao.engine;

import com.sao.agent.SAOAgent;
import org.joml.Vector3f;
import zombie.vehicles.BaseVehicle;
import zombie.core.physics.CarController;

/**
 * [C114] The driving half of the Week One port ([C110]): a live goer
 * who took a car actually enters seat 0 and drives it, through the
 * doorway [C82] mapped - the engine requires no player at the wheel.
 *
 * Everything here is the engine's own lawful surface, verified against
 * the installed jar before use. `enter(0, char)` is Addendum D's seat
 * contract. `tryStartEngine()` (no argument - the boolean form is the
 * cheat path and is NOT taken) bounds the start by the same gameplay a
 * player faces: the engine part's condition and quality may refuse
 * under their own named reasons, and a refusal is HONORED - the goer
 * takes the walk instead, which the Lua face orders as the fallback.
 * `CarController.getClientControls()` stands as written for an NPC at
 * seat 0 - [C82] and this batch's own disassembly both read
 * updateControls() setting its gas/brake fields straight from
 * clientControls with no driver-identity gate, and the keyboard writes
 * it clears run only under isKeyboardControlled(), which an NPC never
 * answers. Steering sign verified the same way: the Left key writes
 * steering-1 and the Right key steering+1, so positive steers right.
 *
 * What is deliberately NOT here, named so it is not mistaken for lost:
 * Week One's ghost driver (a scene-culled, god-moded, invisible
 * IsoPlayer with collisions off) - SAO's driver is the real body in a
 * real seat, and the county can watch it pass. Their forced engine
 * trio (tryStartEngine(true) + engineDoStartingSuccess +
 * engineDoRunning) - that is the cheat path. Their regulator, which
 * its own comments say does not steer - SAO steers, by writing the
 * bearing toward the venture's ground into clientControls. Their
 * horn-at-zombies - no seam for it yet.
 *
 * Verdicts are one-line strings, the transplant discipline.
 */
public final class SAODriver {

    private SAODriver() {
    }

    /** The car is re-found after the walk by name within this many
     * tiles of the body: the claim is facts about a car, not a handle
     * to it ([B19]). */
    private static final float BOARD_RADIUS = 8.0f;
    /** A car parks NEAR an errand, not on it. */
    private static final float ARRIVE_RADIUS = 6.0f;
    /** [C110] Week One's own town figure: their regulator drove at
     * 30 km/h. Carried with credit as the cap's DEFAULT; [C115] makes
     * the cap itself the operator's dial, ordered in from the sandbox
     * screen by the Lua face (Java cannot read SandboxVars), and this
     * figure stands when the order carries none. Everything it scales
     * (the real speedometer) is read. */
    private static final float DEFAULT_SPEED_CAP_KMH = 30.0f;
    private static final float STEER_GAIN = 1.5f;
    /** Ticks the starter gets before the attempt is read as refused. */
    private static final int ENGINE_PATIENCE = 240;
    /** Ticks the driver waits for the promised seats before departing
     * without their late occupants - who then take the walk. */
    private static final int WAIT_PATIENCE = 900;
    /** Ticks of no motion under throttle before the drive is given up
     * as stuck. The engine's own isInvalidChunkAhead brake (verified
     * in updateControls' bytecode) already stops a car at unloaded
     * space; this catches everything else - a wall, a tree, a wreck. */
    private static final int STUCK_PATIENCE = 300;
    /** Ticks the stop phase gets to halt the car before park() takes
     * it by force. */
    private static final int STOP_PATIENCE = 120;
    /** A passenger seated with nothing happening for this long climbs
     * out and walks - the safety net under a driver who never came. */
    private static final int RIDE_PATIENCE = 3600;

    private static final Vector3f FORWARD = new Vector3f();

    // ------------------------------------------------------------------
    // Begin
    // ------------------------------------------------------------------

    /** A driver's trip: walk to the claimed car, start it lawfully,
     * drive to (tx,ty), stop. The car is found now so the walk has
     * somewhere to go; its tile rides back in the verdict. [C115] The
     * speed cap crosses here, read off the sandbox screen by the Lua
     * face - the operator's dial; a non-positive value falls back to
     * the credited default. */
    public static String begin(SAOIsoPlayerShell shell, SAORouteState route,
            SAODriveState state, int radius, String name, int tx, int ty,
            float speedCapKmh) {
        state.mode = "drive";
        state.requested = true;
        state.name = name;
        state.targetX = tx + 0.5f;
        state.targetY = ty + 0.5f;
        state.waitSeats = 0;
        state.speedCapKmh = speedCapKmh > 0.0f
            ? speedCapKmh : DEFAULT_SPEED_CAP_KMH;
        resetTimers(state);
        BaseVehicle vehicle = vehicleNamed(shell, radius, name);
        if (vehicle == null) {
            state.requested = false;
            return "DRIVE_NO_CAR";
        }
        state.phase = "WALK";
        // The walk to the car is an ordinary route - doors, fences,
        // windows and all, through the same machinery every walk uses.
        SAOMovement.begin(shell, route,
            (int) vehicle.getX(), (int) vehicle.getY(), 0);
        return "DRIVE_STARTED car=" + (int) vehicle.getX()
            + "," + (int) vehicle.getY() + " target=" + tx + "," + ty;
    }

    /** A rider's trip: walk to the claimed car, take a passenger seat,
     * ride until the driver parks and climbs out. No destination of
     * their own - company is where they are going ([B19]). */
    public static String beginRide(SAOIsoPlayerShell shell,
            SAORouteState route, SAODriveState state, int radius,
            String name) {
        state.mode = "ride";
        state.requested = true;
        state.name = name;
        state.targetX = 0.0f;
        state.targetY = 0.0f;
        state.waitSeats = 0;
        resetTimers(state);
        BaseVehicle vehicle = vehicleNamed(shell, radius, name);
        if (vehicle == null) {
            state.requested = false;
            return "RIDE_NO_CAR";
        }
        state.phase = "WALK";
        SAOMovement.begin(shell, route,
            (int) vehicle.getX(), (int) vehicle.getY(), 0);
        return "RIDE_STARTED car=" + (int) vehicle.getX()
            + "," + (int) vehicle.getY();
    }

    /** [B19]'s company cap made real: the driver holds at the wheel
     * until this many passengers are seated (or patience ends). Called
     * by the Lua face AFTER the join decision, because the party is
     * only known once people have actually answered the call. */
    public static void waitSeats(SAOIsoPlayerShell shell,
            SAODriveState state, int seats) {
        if (state == null || !state.requested) return;
        if ("WAIT".equals(state.phase) || "START".equals(state.phase)) {
            state.waitSeats = Math.max(0, seats);
        }
        // Already rolling: the call came too late, which is a fact the
        // latecomers' own rides will report as NO_CAR. Nothing forced.
    }

    // ------------------------------------------------------------------
    // Tick
    // ------------------------------------------------------------------

    public static String tick(SAOIsoPlayerShell shell,
            SAORouteState route, SAODriveState state) {
        if (!state.requested) {
            return "IDLE";
        }
        if ("drive".equals(state.mode)) {
            return tickDrive(shell, route, state);
        }
        return tickRide(shell, route, state);
    }

    private static String tickDrive(SAOIsoPlayerShell shell,
            SAORouteState route, SAODriveState state) {
        String phase = state.phase;
        if ("WALK".equals(phase)) {
            String verdict = SAOMovement.tick(shell, route);
            if ("Succeeded".equals(verdict)) {
                return boardAsDriver(shell, state);
            }
            if (verdict.startsWith("Failed") || "IDLE".equals(verdict)) {
                state.requested = false;
                return "DRIVE_WALK_FAILED " + verdict;
            }
            return "Walking";
        }
        if ("START".equals(phase)) {
            return startTick(shell, state);
        }
        if ("WAIT".equals(phase)) {
            return waitTick(shell, state);
        }
        if ("DRIVE".equals(phase)) {
            return driveTick(shell, state);
        }
        if ("STOP".equals(phase)) {
            return stopTick(shell, state);
        }
        state.requested = false;
        return "IDLE";
    }

    // ------------------------------------------------------------------
    // Driver phases
    // ------------------------------------------------------------------

    /** Seat 0, the engine's own contract ([C82] Addendum D), then the
     * lawful start. */
    private static String boardAsDriver(SAOIsoPlayerShell shell,
            SAODriveState state) {
        BaseVehicle vehicle = vehicleNamed(shell,
            (int) BOARD_RADIUS, state.name);
        if (vehicle == null) {
            state.requested = false;
            return "DRIVE_NO_CAR";
        }
        if (vehicle.isSeatOccupied(0) || !vehicle.isSeatInstalled(0)) {
            state.requested = false;
            return "DRIVE_SEAT_TAKEN";
        }
        if (!vehicle.enter(0, shell)) {
            state.requested = false;
            return "DRIVE_BOARD_FAILED";
        }
        try {
            vehicle.setCharacterPosition(shell, 0, "inside");
            vehicle.playPassengerAnim(0, "idle");
        } catch (Throwable positioning) {
            vehicle.exit(shell);
            SAOAgent.log("driver board rolled back: " + positioning);
            state.requested = false;
            return "DRIVE_BOARD_FAILED";
        }
        if (shell.getVehicle() != vehicle) {
            vehicle.exit(shell);
            state.requested = false;
            return "DRIVE_BOARD_FAILED";
        }
        // The lawful start: no argument, no cheat flag. The bounds are
        // the same ones a player faces, and the venture's own canTake
        // gate ([B19]) already answered keys and hotwire.
        vehicle.tryStartEngine();
        // An occupied car's physics needs waking the same way a
        // player's entry wakes it - the engine's own public call,
        // verified: it grants the activity window the starter and the
        // first throttle press run inside.
        vehicle.setPhysicsActive(true);
        state.phase = "START";
        state.engineTries = 0;
        return "ENGINE_TURNING";
    }

    private static String startTick(SAOIsoPlayerShell shell,
            SAODriveState state) {
        BaseVehicle vehicle = shell.getVehicle();
        if (vehicle == null || vehicle.getDriver() != shell) {
            state.requested = false;
            return "DRIVE_LOST_CAR";
        }
        if (vehicle.isEngineRunning()) {
            state.phase = state.waitSeats > 0 ? "WAIT" : "DRIVE";
            state.waitTicks = 0;
            vehicle.setPhysicsActive(true);
            return "ENGINE_RUNNING";
        }
        zombie.vehicles.BaseVehicle.engineStateTypes engineState =
            vehicle.getEngineState();
        if (engineState == zombie.vehicles.BaseVehicle.engineStateTypes.StartingFailed
            || engineState == zombie.vehicles.BaseVehicle.engineStateTypes.Idle) {
            // The engine refused under its own named reasons -
            // condition, quality, power. A refusal is a fact about the
            // car, not an obstacle to route around: out, and the walk.
            climbOut(vehicle, shell);
            state.requested = false;
            return "DRIVE_ENGINE_REFUSED";
        }
        state.engineTries++;
        if (state.engineTries > ENGINE_PATIENCE) {
            climbOut(vehicle, shell);
            state.requested = false;
            return "DRIVE_ENGINE_REFUSED";
        }
        return "ENGINE_TURNING";
    }

    /** Holding at the wheel for the promised seats. Bums on seats are
     * counted, not tracked - whoever is in the car when it fills (or
     * when patience ends) is who it carries. */
    private static String waitTick(SAOIsoPlayerShell shell,
            SAODriveState state) {
        BaseVehicle vehicle = shell.getVehicle();
        if (vehicle == null || vehicle.getDriver() != shell) {
            state.requested = false;
            return "DRIVE_LOST_CAR";
        }
        CarController.ClientControls controls =
            vehicle.getController().getClientControls();
        controls.forward = false;
        controls.backward = false;
        controls.brake = true;
        controls.steering = 0.0f;
        int seated = 0;
        int seats = vehicle.getMaxPassengers();
        for (int i = 1; i < seats; i++) {
            if (vehicle.isSeatInstalled(i) && vehicle.isSeatOccupied(i)) {
                seated++;
            }
        }
        if (seated >= state.waitSeats) {
            state.phase = "DRIVE";
            return "Driving";
        }
        state.waitTicks++;
        if (state.waitTicks > WAIT_PATIENCE) {
            state.phase = "DRIVE";
            return "Driving";
        }
        return "Waiting";
    }

    /** The drive itself: steer by the bearing to the venture's ground,
     * hold the town speed, brake to a stop near it. */
    private static String driveTick(SAOIsoPlayerShell shell,
            SAODriveState state) {
        BaseVehicle vehicle = shell.getVehicle();
        if (vehicle == null || vehicle.getDriver() != shell) {
            state.requested = false;
            return "DRIVE_LOST_CAR";
        }
        CarController.ClientControls controls =
            vehicle.getController().getClientControls();
        float dx = state.targetX - vehicle.getX();
        float dy = state.targetY - vehicle.getY();
        float distance = (float) Math.sqrt(dx * dx + dy * dy);
        if (distance <= ARRIVE_RADIUS) {
            state.phase = "STOP";
            state.stopTicks = 0;
            controls.forward = false;
            controls.backward = false;
            controls.brake = true;
            controls.steering = 0.0f;
            return "Arriving";
        }
        // The bearing. getForwardVector is (x east, y up, z south) -
        // the same plane as tile (x, y) - so the 2D cross of forward
        // and to-target is positive exactly when the target lies to
        // the vehicle's RIGHT, which is the positive-steering side
        // (verified: the Left key writes -1, the Right key +1).
        Vector3f forward = vehicle.getForwardVector(FORWARD);
        if (forward == null) {
            controls.forward = false;
            controls.brake = true;
            return "Driving";
        }
        float cross = forward.x * dy - forward.z * dx;
        controls.steering = clamp(cross * STEER_GAIN, -1.0f, 1.0f);
        float speed = Math.abs(vehicle.getCurrentSpeedKmHour());
        // [C115] The operator's dial, ordered in at begin; the credited
        // default stands when the state never carried one (a ride
        // never sets it, and a drive ordered by older Lua).
        float cap = state.speedCapKmh > 0.0f
            ? state.speedCapKmh : DEFAULT_SPEED_CAP_KMH;
        if (speed > cap) {
            controls.forward = false;
            controls.brake = true;
            state.stuckTicks = 0;
        } else {
            controls.forward = true;
            controls.backward = false;
            controls.brake = false;
            // No motion under throttle is a wall, a wreck, a tree, or
            // the engine's own unloaded-space brake - none of which a
            // steering wheel fixes. Patience, then out, and the walk.
            if (speed < 2.0f) {
                state.stuckTicks++;
            } else {
                state.stuckTicks = 0;
            }
            if (state.stuckTicks > STUCK_PATIENCE) {
                finish(shell, vehicle);
                state.requested = false;
                return "DRIVE_STUCK";
            }
        }
        return "Driving";
    }

    private static String stopTick(SAOIsoPlayerShell shell,
            SAODriveState state) {
        BaseVehicle vehicle = shell.getVehicle();
        if (vehicle == null || vehicle.getDriver() != shell) {
            state.requested = false;
            return "DRIVE_LOST_CAR";
        }
        CarController.ClientControls controls =
            vehicle.getController().getClientControls();
        controls.forward = false;
        controls.backward = false;
        controls.brake = true;
        controls.steering = 0.0f;
        float speed = Math.abs(vehicle.getCurrentSpeedKmHour());
        state.stopTicks++;
        if (speed <= 3.0f || state.stopTicks > STOP_PATIENCE) {
            finish(shell, vehicle);
            state.requested = false;
            return "Succeeded";
        }
        return "Arriving";
    }

    /** Park and climb out, the engine's own calls: park() halts the
     * car and resets the controls, shutOff() is the key turned off,
     * and the unseat pairs the flag and the mesh the way [B1]/[C4]
     * taught - a released seat never keeps a phantom passenger. */
    private static void finish(SAOIsoPlayerShell shell,
            BaseVehicle vehicle) {
        try {
            vehicle.getController().park();
        } catch (Throwable parked) {
            SAOAgent.log("park threw: " + parked);
        }
        try {
            vehicle.shutOff();
        } catch (Throwable off) {
            SAOAgent.log("shutOff threw: " + off);
        }
        SAONeeds.unseatFromVehicle(shell);
    }

    private static void climbOut(BaseVehicle vehicle,
            SAOIsoPlayerShell shell) {
        // Not moving; no park needed, but the controls we held must not
        // outlive the driver.
        try {
            vehicle.getController().getClientControls().reset();
        } catch (Throwable reset) {
            SAOAgent.log("controls reset threw: " + reset);
        }
        SAONeeds.unseatFromVehicle(shell);
    }

    // ------------------------------------------------------------------
    // Rider phases
    // ------------------------------------------------------------------

    private static String tickRide(SAOIsoPlayerShell shell,
            SAORouteState route, SAODriveState state) {
        if ("WALK".equals(state.phase)) {
            String verdict = SAOMovement.tick(shell, route);
            if ("Succeeded".equals(verdict)) {
                return boardAsRider(shell, state);
            }
            if (verdict.startsWith("Failed") || "IDLE".equals(verdict)) {
                state.requested = false;
                return "RIDE_WALK_FAILED " + verdict;
            }
            return "Walking";
        }
        // RIDE
        BaseVehicle vehicle = shell.getVehicle();
        if (vehicle == null) {
            // Something already unseated them; that is the ride over.
            state.requested = false;
            return "Succeeded";
        }
        state.rideTicks++;
        BaseVehicle.engineStateTypes engineState = null;
        try {
            engineState = vehicle.getEngineState();
        } catch (Throwable read) {
            SAOAgent.log("ride engine read threw: " + read);
        }
        boolean driverGone = vehicle.getDriver() == null;
        boolean atRest = false;
        try {
            atRest = vehicle.isStopped();
        } catch (Throwable rest) {
            SAOAgent.log("ride rest read threw: " + rest);
        }
        if ((driverGone && atRest)
            || state.rideTicks > RIDE_PATIENCE) {
            // The driver parked and climbed out, or never came at all.
            SAONeeds.unseatFromVehicle(shell);
            state.requested = false;
            return state.rideTicks > RIDE_PATIENCE
                ? "RIDE_ABANDONED" : "Succeeded";
        }
        // The engine refused under the driver: out with them, and the
        // walk after - reported as the ride ending, not as an error.
        if (engineState == BaseVehicle.engineStateTypes.StartingFailed) {
            SAONeeds.unseatFromVehicle(shell);
            state.requested = false;
            return "RIDE_ENGINE_REFUSED";
        }
        return "Riding";
    }

    /** A passenger seat, the [B1] boarding idiom whole: enter claims,
     * setCharacterPosition moves the mesh, and a positioning throw
     * rolls the claim back - a failed action never leaves a seat
     * occupied by a body standing in the road. */
    private static String boardAsRider(SAOIsoPlayerShell shell,
            SAODriveState state) {
        BaseVehicle vehicle = vehicleNamed(shell,
            (int) BOARD_RADIUS, state.name);
        if (vehicle == null) {
            state.requested = false;
            return "RIDE_NO_CAR";
        }
        int seats = vehicle.getMaxPassengers();
        for (int i = 1; i < seats; i++) {
            if (vehicle.isSeatInstalled(i) && !vehicle.isSeatOccupied(i)) {
                if (vehicle.enter(i, shell)) {
                    try {
                        vehicle.setCharacterPosition(shell, i, "inside");
                        vehicle.playPassengerAnim(i, "idle");
                    } catch (Throwable positioning) {
                        vehicle.exit(shell);
                        SAOAgent.log("rider board rolled back at seat "
                            + i + ": " + positioning);
                        state.requested = false;
                        return "RIDE_BOARD_FAILED";
                    }
                    if (shell.getVehicle() != vehicle) {
                        vehicle.exit(shell);
                        state.requested = false;
                        return "RIDE_BOARD_FAILED";
                    }
                    state.phase = "RIDE";
                    state.rideTicks = 0;
                    return "Riding";
                }
            }
        }
        state.requested = false;
        return "RIDE_NO_SEAT";
    }

    // ------------------------------------------------------------------
    // Cancel and shared
    // ------------------------------------------------------------------

    public static String cancel(SAOIsoPlayerShell shell,
            SAORouteState route, SAODriveState state) {
        if (state == null || !state.requested) {
            return "DRIVE_CANCELLED";
        }
        if ("WALK".equals(state.phase)) {
            SAOMovement.cancel(shell, route);
        } else {
            BaseVehicle vehicle = shell.getVehicle();
            if (vehicle != null) {
                if ("drive".equals(state.mode)) {
                    finish(shell, vehicle);
                } else {
                    SAONeeds.unseatFromVehicle(shell);
                }
            }
        }
        state.requested = false;
        state.phase = "NONE";
        return "DRIVE_CANCELLED";
    }

    private static void resetTimers(SAODriveState state) {
        state.engineTries = 0;
        state.waitTicks = 0;
        state.stuckTicks = 0;
        state.stopTicks = 0;
        state.rideTicks = 0;
        state.phase = "NONE";
    }

    /** The claimed car by its pool name, nearest within radius of the
     * body - the same re-finding tolerance spendVehicleFuel uses, the
     * same spelling ([B31]). */
    private static BaseVehicle vehicleNamed(SAOIsoPlayerShell shell,
            int radius, String name) {
        try {
            if (name == null) return null;
            zombie.iso.IsoCell cell = shell.getCell();
            if (cell == null) return null;
            float sx = shell.getX(), sy = shell.getY();
            BaseVehicle best = null;
            float bestD2 = (float) radius * radius;
            for (BaseVehicle vehicle : cell.getVehicles()) {
                if (vehicle == null) continue;
                if (!name.equals(SAONeeds.poolName(vehicle))) continue;
                float dx = vehicle.getX() - sx, dy = vehicle.getY() - sy;
                float d2 = dx * dx + dy * dy;
                if (d2 <= bestD2) {
                    bestD2 = d2;
                    best = vehicle;
                }
            }
            return best;
        } catch (Throwable throwable) {
            SAOAgent.log("vehicleNamed threw: " + throwable);
            return null;
        }
    }

    private static float clamp(float value, float low, float high) {
        return value < low ? low : (value > high ? high : value);
    }
}