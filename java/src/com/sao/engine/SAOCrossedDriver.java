package com.sao.engine;

import com.sao.agent.SAOAgent;
import zombie.characters.IsoZombie;
import zombie.vehicles.BaseVehicle;

/**
 * [C116] The driving half of the crossed seam ([A13]/[A32]): a crossed
 * body - an IsoZombie the sister's controller owns - takes the wheel of
 * the dead group's runner and drives it. The survivor driver
 * (SAODriver) is untouched; this is the map's second entry, for the
 * body type the first one refuses.
 *
 * Everything the two trips share is the ENGINE's own character-typed
 * surface, verified against the shipped jar before use: `enter(0, char)`
 * and `exit(char)` take any IsoGameCharacter with no driver-identity
 * gate (Addendum D / F-067), `getDriver()` answers an IsoGameCharacter,
 * and `setCharacterPosition`/`playPassengerAnim` are the same calls the
 * survivor's boarding makes. `tryStartEngine()` (no argument) bounds the
 * start by the engine's own condition, and a refusal is HONORED - the
 * body climbs out and the verdict ends the trip; the crossed keep every
 * capability and no capability starts an engine that will not start.
 *
 * What the two trips cannot share is the WALK. The survivor's walk is
 * SAOMovement - captured route nodes, door and window transitions,
 * playerMoveDir and animation strafe - and that machinery is the
 * living's. The crossed walk the way the dead walk: `pathToLocationF`,
 * the engine's own zombie pathing, one leg per scan, the same call the
 * sister's hunt uses. No route is captured, no intent is driven, and
 * no door is opened by a body whose person's way with doors went with
 * them ([A12]: the strips are omissions - the crossed take the yard as
 * they find it).
 *
 * No WAIT phase: the crossed wait for nobody. The company cap and its
 * patience are the living's debts.
 *
 * Verdicts are one-line strings, the transplant discipline; the caller
 * (the sister's ZAO_Crossed pass) reads them with the same machine it
 * reads the survivor's.
 */
public final class SAOCrossedDriver {

    private SAOCrossedDriver() {
    }

    /** The car is re-found by name within this many tiles of the body:
     * the same claim tolerance the survivor's driver re-finds with. */
    private static final float BOARD_RADIUS = 8.0f;
    private static final int ENGINE_PATIENCE = 240;
    /** Legs of the dead's walk before the trip is given up: one leg per
     * scan from the sister's pass, so this is scans of patience, and a
     * body that cannot reach its car parks it as a fact about the car,
     * never as an obstacle to route around. */
    private static final int WALK_PATIENCE = 900;

    /** A crossed body's trip: walk to the claimed car as the dead walk,
     * start it lawfully, drive to (tx,ty), stop, climb out. */
    public static String begin(IsoZombie zombie, SAODriveState state,
            int radius, String name, int tx, int ty, float speedCapKmh) {
        state.mode = "drive";
        state.requested = true;
        state.name = name;
        state.targetX = tx + 0.5f;
        state.targetY = ty + 0.5f;
        state.waitSeats = 0;
        state.speedCapKmh = speedCapKmh > 0.0f
            ? speedCapKmh : SAODriveLaw.DEFAULT_SPEED_CAP_KMH;
        resetTimers(state);
        BaseVehicle vehicle = vehicleNamed(zombie, radius, name);
        if (vehicle == null) {
            state.requested = false;
            return "DRIVE_NO_CAR";
        }
        state.phase = "XWALK";
        // The first leg is issued here so the walk starts between scans;
        // every later leg is re-issued by tick, the same cadence the
        // sister's own hunt drives paths at.
        pathToward(zombie, vehicle);
        return "DRIVE_STARTED car=" + (int) vehicle.getX()
            + "," + (int) vehicle.getY() + " target=" + tx + "," + ty;
    }

    public static String tick(IsoZombie zombie, SAODriveState state) {
        if (!state.requested) {
            return "IDLE";
        }
        String phase = state.phase;
        if ("XWALK".equals(phase)) {
            return walkTick(zombie, state);
        }
        if ("START".equals(phase)) {
            return startTick(zombie, state);
        }
        if ("DRIVE".equals(phase)) {
            return driveTick(zombie, state);
        }
        if ("STOP".equals(phase)) {
            return stopTick(zombie, state);
        }
        state.requested = false;
        return "IDLE";
    }

    // ------------------------------------------------------------------
    // Phases
    // ------------------------------------------------------------------

    /** The dead's walk: one leg per scan toward the car, arrived when
     * the body stands in the claim circle. */
    private static String walkTick(IsoZombie zombie, SAODriveState state) {
        BaseVehicle vehicle = vehicleNamed(zombie, (int) BOARD_RADIUS,
            state.name);
        if (vehicle == null) {
            state.requested = false;
            return "DRIVE_NO_CAR";
        }
        float dx = vehicle.getX() - zombie.getX();
        float dy = vehicle.getY() - zombie.getY();
        if (dx * dx + dy * dy
                <= BOARD_RADIUS * BOARD_RADIUS) {
            return boardAsDriver(zombie, state, vehicle);
        }
        state.walkTicks++;
        if (state.walkTicks > WALK_PATIENCE) {
            state.requested = false;
            return "DRIVE_WALK_FAILED patience";
        }
        pathToward(zombie, vehicle);
        return "Walking";
    }

    /** Seat 0, the engine's own contract, then the lawful start - the
     * same board the survivor's driver makes, on the same calls; a
     * positioning throw rolls the claim back the same way. */
    private static String boardAsDriver(IsoZombie zombie,
            SAODriveState state, BaseVehicle vehicle) {
        if (vehicle.isSeatOccupied(0) || !vehicle.isSeatInstalled(0)) {
            state.requested = false;
            return "DRIVE_SEAT_TAKEN";
        }
        if (!vehicle.enter(0, zombie)) {
            state.requested = false;
            return "DRIVE_BOARD_FAILED";
        }
        try {
            vehicle.setCharacterPosition(zombie, 0, "inside");
            vehicle.playPassengerAnim(0, "idle");
        } catch (Throwable positioning) {
            vehicle.exit(zombie);
            SAOAgent.log("crossed board rolled back: " + positioning);
            state.requested = false;
            return "DRIVE_BOARD_FAILED";
        }
        if (zombie.getVehicle() != vehicle) {
            vehicle.exit(zombie);
            state.requested = false;
            return "DRIVE_BOARD_FAILED";
        }
        vehicle.tryStartEngine();
        vehicle.setPhysicsActive(true);
        state.phase = "START";
        state.engineTries = 0;
        return "ENGINE_TURNING";
    }

    private static String startTick(IsoZombie zombie, SAODriveState state) {
        BaseVehicle vehicle = zombie.getVehicle();
        if (vehicle == null || vehicle.getDriver() != zombie) {
            state.requested = false;
            return "DRIVE_LOST_CAR";
        }
        if (vehicle.isEngineRunning()) {
            state.phase = "DRIVE";
            vehicle.setPhysicsActive(true);
            return "ENGINE_RUNNING";
        }
        BaseVehicle.engineStateTypes engineState = vehicle.getEngineState();
        if (engineState == BaseVehicle.engineStateTypes.StartingFailed
            || engineState == BaseVehicle.engineStateTypes.Idle) {
            climbOut(vehicle, zombie);
            state.requested = false;
            return "DRIVE_ENGINE_REFUSED";
        }
        state.engineTries++;
        if (state.engineTries > ENGINE_PATIENCE) {
            climbOut(vehicle, zombie);
            state.requested = false;
            return "DRIVE_ENGINE_REFUSED";
        }
        return "ENGINE_TURNING";
    }

    /** The drive itself: the vehicle law the survivor's driver holds
     * too, called with the crossed's own unseat - the engine's trio
     * with no needs machinery after it, because the dead have none
     * ([SAODriveLaw]). */
    private static String driveTick(IsoZombie zombie, SAODriveState state) {
        return SAODriveLaw.driveTick(zombie, state,
            vehicle -> finish(zombie, vehicle));
    }

    /** Halting near the ordered ground: the law's halt, the crossed's
     * own unseat at the end of it. */
    private static String stopTick(IsoZombie zombie, SAODriveState state) {
        return SAODriveLaw.stopTick(zombie, state,
            vehicle -> finish(zombie, vehicle));
    }

    // ------------------------------------------------------------------
    // Shared
    // ------------------------------------------------------------------

    /** Park, shut off, climb out - the engine's own calls, the same
     * unseating the survivor's finish makes minus the needs machinery
     * that is the living's. */
    private static void finish(IsoZombie zombie, BaseVehicle vehicle) {
        try {
            vehicle.getController().park();
        } catch (Throwable parked) {
            SAOAgent.log("crossed park threw: " + parked);
        }
        try {
            vehicle.shutOff();
        } catch (Throwable off) {
            SAOAgent.log("crossed shutOff threw: " + off);
        }
        try {
            vehicle.exit(zombie);
        } catch (Throwable out) {
            SAOAgent.log("crossed exit threw: " + out);
        }
    }

    private static void climbOut(BaseVehicle vehicle, IsoZombie zombie) {
        try {
            vehicle.getController().getClientControls().reset();
        } catch (Throwable reset) {
            SAOAgent.log("crossed controls reset threw: " + reset);
        }
        try {
            vehicle.exit(zombie);
        } catch (Throwable out) {
            SAOAgent.log("crossed exit threw: " + out);
        }
    }

    private static void pathToward(IsoZombie zombie, BaseVehicle vehicle) {
        try {
            zombie.pathToLocationF(
                vehicle.getX(), vehicle.getY(), vehicle.getZ());
        } catch (Throwable path) {
            SAOAgent.log("crossed path leg threw: " + path);
        }
    }

    private static void resetTimers(SAODriveState state) {
        state.engineTries = 0;
        state.waitTicks = 0;
        state.stuckTicks = 0;
        state.stopTicks = 0;
        state.rideTicks = 0;
        state.walkTicks = 0;
        state.phase = "NONE";
    }

    /** The claimed car by its pool name, nearest within radius of the
     * body - the same re-finding tolerance and the same spelling as the
     * survivor's ([B31]); the finding itself is the law's, shared with
     * the survivor's driver, so only the body type differs here. */
    private static BaseVehicle vehicleNamed(IsoZombie zombie,
            int radius, String name) {
        return SAODriveLaw.vehicleNamed(zombie, radius, name);
    }
}