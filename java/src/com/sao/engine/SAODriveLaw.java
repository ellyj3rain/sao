package com.sao.engine;

import com.sao.agent.SAOAgent;
import org.joml.Vector3f;
import zombie.characters.IsoGameCharacter;
import zombie.core.physics.CarController;
import zombie.vehicles.BaseVehicle;

/**
 * [C116] The vehicle law both drivers hold, lifted whole out of the
 * two drivers so it exists once ([B31]): the bearing, the cap and the
 * patience of the DRIVE phase, the halt of the STOP phase, and the
 * claimed car's re-finding by pool name. The drivers differ in who
 * they are and how they climb out; the wheels do not care, so the law
 * is typed on IsoGameCharacter - the class both kinds of body share -
 * and takes each driver's own unseat.
 *
 * Every call here is the engine's own character-typed surface,
 * verified against the shipped jar before use ([C82]/[C114]/[A32]):
 * `getDriver()` answers an IsoGameCharacter, so the identity check is
 * one comparison whatever is at the wheel, and
 * `CarController.getClientControls()` stands as written for an NPC at
 * seat 0 - updateControls() sets its gas/brake fields straight from
 * clientControls with no driver-identity gate. Steering sign verified
 * the same way: the Left key writes steering-1 and the Right key
 * steering+1, so positive steers right.
 *
 * Verdicts are one-line strings, the transplant discipline.
 */
public final class SAODriveLaw {

    private SAODriveLaw() {
    }

    /** The unseat a finished drive demands - one definition per driver:
     * the crossed climb out bare; the living unseat through the needs
     * pairing ([B1]/[C4]), which is the living's own machinery. */
    public interface Unseat {
        void unseat(BaseVehicle vehicle);
    }

    /** A car parks NEAR an errand, not on it. */
    public static final float ARRIVE_RADIUS = 6.0f;
    /** [C110] Week One's own town figure: their regulator drove at
     * 30 km/h. Carried with credit as the cap's DEFAULT; [C115] makes
     * the cap itself the operator's dial, ordered in from the sandbox
     * screen by the Lua face (Java cannot read SandboxVars), and this
     * figure stands when the order carries none. Everything it scales
     * (the real speedometer) is read. */
    public static final float DEFAULT_SPEED_CAP_KMH = 30.0f;
    public static final float STEER_GAIN = 1.5f;
    /** Ticks of no motion under throttle before the drive is given up
     * as stuck. The engine's own isInvalidChunkAhead brake (verified
     * in updateControls' bytecode) already stops a car at unloaded
     * space; this catches everything else - a wall, a tree, a wreck. */
    public static final int STUCK_PATIENCE = 300;
    /** Ticks the stop phase gets to halt the car before park() takes
     * it by force. */
    public static final int STOP_PATIENCE = 120;

    private static final Vector3f FORWARD = new Vector3f();

    /** The drive itself: steer by the bearing to the ordered ground,
     * hold the cap, brake to a stop near it. Whoever is at the wheel
     * when the phase began must still be, or the trip is over -
     * DRIVE_LOST_CAR is the same verdict for the living and the
     * crossed. */
    public static String driveTick(IsoGameCharacter who,
            SAODriveState state, Unseat unseat) {
        BaseVehicle vehicle = who.getVehicle();
        if (vehicle == null || vehicle.getDriver() != who) {
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
        // the vehicle's RIGHT, which is the positive-steering side.
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
        // default stands when the state never carried one.
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
                unseat.unseat(vehicle);
                state.requested = false;
                return "DRIVE_STUCK";
            }
        }
        return "Driving";
    }

    /** Halting near the ordered ground: brake, then the driver's own
     * unseat once the car stands (or when patience ends and park()
     * must take it by force). Succeeded is the caller's to name - the
     * trip it ends differs (the survivor's errand, the crossed's
     * ground); the halt does not. */
    public static String stopTick(IsoGameCharacter who,
            SAODriveState state, Unseat unseat) {
        BaseVehicle vehicle = who.getVehicle();
        if (vehicle == null || vehicle.getDriver() != who) {
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
            unseat.unseat(vehicle);
            state.requested = false;
            return "Succeeded";
        }
        return "Arriving";
    }

    /** The claimed car by its pool name, nearest within radius of the
     * body - the same re-finding tolerance and the same spelling
     * ([B19]/[B31]); only the body differs, and the law is typed on
     * the class both kinds of body share. */
    public static BaseVehicle vehicleNamed(IsoGameCharacter who,
            int radius, String name) {
        try {
            if (name == null) return null;
            zombie.iso.IsoCell cell = who.getCell();
            if (cell == null) return null;
            float sx = who.getX(), sy = who.getY();
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