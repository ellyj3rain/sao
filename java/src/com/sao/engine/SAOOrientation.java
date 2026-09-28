package com.sao.engine;

import java.lang.ref.WeakReference;
import java.util.WeakHashMap;
import se.krka.kahlua.vm.KahluaTable;
import zombie.Lua.LuaManager;
import zombie.ai.states.ClimbOverFenceState;
import zombie.ai.states.ClimbThroughWindowState;
import zombie.ai.states.ClimbOverWallState;
import zombie.characters.IsoGameCharacter;
import zombie.iso.IsoCell;
import zombie.iso.Vector2;

/** One finite acoustic orienting owner; it neither requests nor cancels locomotion. */
public final class SAOOrientation {
    private static final WeakHashMap<SAOIsoPlayerShell, State> STATES = new WeakHashMap<>();
    private static final float DURATION = 2.4f;
    private static final float MAX_HEAD = 1.0f;
    private static final class State {
        final WeakReference<IsoCell> cell;
        long consumed;
        boolean active, bodyTurn, layerReady;
        String mode = "none", cue = "", action = "", reason = "idle", phase = "idle";
        float x, y, readiness, steadiness, elapsed, horizontal, required, maintained;
        State(IsoCell value) { cell = new WeakReference<>(value); }
    }
    private SAOOrientation() {}

    public static synchronized boolean request(IsoGameCharacter body, String cueId,
            float x, float y, float readiness, float steadiness, boolean allowBodyTurn) {
        if (!(body instanceof SAOIsoPlayerShell shell) || cueId == null || cueId.length() > 128
                || !Float.isFinite(x) || !Float.isFinite(y) || !unit(readiness) || !unit(steadiness)
                || readiness <= 0 || unavailable(shell) != null) return false;
        var cue = SAOWorldSoundPulses.acquired(shell, cueId, x, y);
        if (cue == null) return false;
        State state = STATES.get(shell);
        if (state == null || state.cell.get() != shell.getCell()) {
            state = new State(shell.getCell()); STATES.put(shell, state);
        }
        if (state.active || cue.sequence() <= state.consumed) return false;
        if (!SAOOrientationAnimation.ensure(shell)) {
            state.reason = SAOOrientationAnimation.readFailure() == null ? "animation-unavailable"
                : SAOOrientationAnimation.readFailure();
            return false;
        }
        state.consumed = cue.sequence(); state.cue = cueId;
        state.mode = "sound"; state.action = ""; state.required = 0; state.maintained = 0;
        state.x = x; state.y = y; state.readiness = readiness; state.steadiness = steadiness;
        state.bodyTurn = allowBodyTurn; state.layerReady = true; state.active = true;
        state.elapsed = 0; state.horizontal = 0; state.phase = "attend"; state.reason = "audible-cue";
        shell.setVariable(SAOOrientationAnimation.ACTIVE, true);
        shell.setVariable(SAOOrientationAnimation.HORIZONTAL, 0f);
        shell.setVariable(SAOOrientationAnimation.VERTICAL, 0f);
        return true;
    }

    /** A finite deliberate watch/cover posture. Admission starts native body
     * and head orientation; completion means the body remained available and
     * faced the stated target for the requested bounded interval. */
    public static synchronized boolean requestPosture(IsoGameCharacter body, String actionId,
            float x, float y, float readiness, float steadiness, float durationSeconds) {
        if (!(body instanceof SAOIsoPlayerShell shell) || actionId == null
                || actionId.isEmpty() || actionId.length() > 128
                || !Float.isFinite(x) || !Float.isFinite(y) || !unit(readiness)
                || !unit(steadiness) || readiness <= 0 || !Float.isFinite(durationSeconds)
                || durationSeconds < .5f || durationSeconds > 30f
                || unavailable(shell) != null || moving(shell)) return false;
        State state = STATES.get(shell);
        if (state != null && state.active) {
            return "posture".equals(state.mode) && actionId.equals(state.action);
        }
        if (state == null || state.cell.get() != shell.getCell()) {
            state = new State(shell.getCell()); STATES.put(shell, state);
        }
        if (!SAOOrientationAnimation.ensure(shell)) {
            state.reason = SAOOrientationAnimation.readFailure() == null ? "animation-unavailable"
                : SAOOrientationAnimation.readFailure();
            return false;
        }
        state.mode = "posture"; state.action = actionId; state.cue = "";
        state.x = x; state.y = y; state.readiness = readiness; state.steadiness = steadiness;
        state.bodyTurn = true; state.layerReady = true; state.active = true;
        state.elapsed = 0; state.horizontal = 0; state.required = durationSeconds;
        state.maintained = 0; state.phase = "turn"; state.reason = "posture-admitted";
        shell.setVariable(SAOOrientationAnimation.ACTIVE, true);
        shell.setVariable(SAOOrientationAnimation.HORIZONTAL, 0f);
        shell.setVariable(SAOOrientationAnimation.VERTICAL, 0f);
        return true;
    }

    /** Called before native postupdate: native action graph/animation consumes these inputs. */
    public static synchronized void beforePostUpdate(SAOIsoPlayerShell shell) {
        State state = STATES.get(shell);
        if (state == null || !state.active) return;
        String unavailable = unavailable(shell);
        if (state.cell.get() != shell.getCell()) unavailable = "body-owner-changed";
        var player = SAOOrientationAnimation.nativePlayer(shell);
        if (player == null || !player.hasSkinningData()) {
            state.layerReady = false; unavailable = SAOOrientationAnimation.readFailure() == null
                ? "animation-unavailable" : SAOOrientationAnimation.readFailure();
        }
        if (unavailable != null) { stop(shell, state, unavailable); return; }
        float dt = shell.getAnimationTimeDelta();
        if (!Float.isFinite(dt) || dt < 0) { stop(shell, state, "native-time-unavailable"); return; }
        state.elapsed += dt;
        if ("sound".equals(state.mode)) {
            if (state.elapsed >= DURATION) { stop(shell, state, "expired"); return; }
        }
        if ("posture".equals(state.mode) && moving(shell)) {
            stop(shell, state, "body-moving"); return;
        }
        if ("posture".equals(state.mode)
                && state.elapsed >= state.required + 8f) {
            stop(shell, state, "posture-timeout"); return;
        }
        float delay = .10f + (1 - state.readiness) * .55f;
        if (state.elapsed < delay) return;
        float dx = state.x - shell.getX(), dy = state.y - shell.getY();
        if (Math.abs(dx) + Math.abs(dy) < .001f) { stop(shell, state, "at-cue"); return; }
        float desired = (float) Math.atan2(dy, dx);
        boolean pivot = state.bodyTurn && !moving(shell);
        if (pivot) shell.faceLocationF(state.x, state.y);
        float base = SAOSenses.nativeGazeAngle(shell); // native bHeadLookAround remains false
        float turn = wrap(desired - base);
        float sweep = "sound".equals(state.mode) && state.elapsed > .7f && state.elapsed < 1.8f
            ? .18f * (float) Math.sin((state.elapsed - .7f) / 1.1f * Math.PI * 2) : 0;
        float target = "sound".equals(state.mode) && state.elapsed > 1.9f ? 0
            : Math.max(-MAX_HEAD, Math.min(MAX_HEAD, turn + sweep));
        float maxStep = dt * (1.2f + 2.4f * state.steadiness);
        state.horizontal += Math.max(-maxStep, Math.min(maxStep, target - state.horizontal));
        state.phase = "posture".equals(state.mode) ? "hold"
            : state.elapsed > 1.9f ? "return" : state.elapsed > .7f ? "sweep" : "turn";
        shell.setVariable(SAOOrientationAnimation.HORIZONTAL, state.horizontal);
        if ("posture".equals(state.mode)) {
            float residual = Math.abs(wrap(desired - SAOSenses.nativeGazeAngle(shell)));
            if (residual <= .35f) state.maintained += dt;
            else state.maintained = Math.max(0, state.maintained - dt);
            if (state.maintained >= state.required) stop(shell, state, "completed");
        }
    }

    /** Preserve PZ state/action turn limits; only our admitted idle body turn is scaled. */
    public static synchronized float turnMultiplier(SAOIsoPlayerShell shell) {
        State state = STATES.get(shell);
        return state != null && state.active && state.bodyTurn && !moving(shell)
            && unavailable(shell) == null ? .3f + .7f * state.steadiness : 1;
    }

    private static boolean moving(SAOIsoPlayerShell shell) {
        return shell.isPlayerMoving() || shell.hasPath() || shell.playerMoveDir.getLengthSquared() > .0001f;
    }
    private static String unavailable(SAOIsoPlayerShell shell) {
        if (shell.removalPending || shell.getCurrentSquare() == null || shell.getCell() == null
                || shell.getCell().getGridSquare(shell.getCurrentSquare().getX(), shell.getCurrentSquare().getY(),
                    shell.getCurrentSquare().getZ()) != shell.getCurrentSquare()) return "body-unavailable";
        if (shell.isDead() || shell.isAsleep() || shell.getVehicle() != null) return "body-busy";
        if (shell.isAiming() || shell.isAttackStarted() || shell.isCharging || shell.isInitiateAttack()) return "combat";
        if (!shell.getCharacterActions().isEmpty()) return "timed-action";
        var current = shell.getCurrentState();
        if (shell.isClimbing() || current == ClimbOverFenceState.instance()
                || current == ClimbThroughWindowState.instance() || current == ClimbOverWallState.instance()
                || shell.getActionContext().hasEventOccurred("EventClimbFence")
                || shell.getActionContext().hasEventOccurred("EventClimbWindow")) return "crossing";
        if (!SAOOrientationAnimation.admittedRoot(shell.getActionContext().getCurrentStateName())) return "native-action";
        return null;
    }
    private static boolean unit(float n) { return Float.isFinite(n) && n >= 0 && n <= 1; }
    private static float wrap(float n) { return (float) Math.atan2(Math.sin(n), Math.cos(n)); }
    private static void stop(SAOIsoPlayerShell shell, State state, String reason) {
        state.active = false; state.phase = "idle"; state.reason = reason; state.horizontal = 0;
        shell.setVariable(SAOOrientationAnimation.ACTIVE, false);
        shell.setVariable(SAOOrientationAnimation.HORIZONTAL, 0f);
        shell.setVariable(SAOOrientationAnimation.VERTICAL, 0f);
    }
    public static synchronized void clear(IsoGameCharacter body) {
        if (body instanceof SAOIsoPlayerShell shell) {
            State state = STATES.get(shell);
            if (state != null) stop(shell, state, "released");
        }
    }
    public static synchronized void clearPosture(IsoGameCharacter body, String actionId) {
        if (body instanceof SAOIsoPlayerShell shell) {
            State state = STATES.get(shell);
            if (state != null && "posture".equals(state.mode)
                    && state.action.equals(actionId == null ? "" : actionId)) {
                stop(shell, state, "released");
            }
        }
    }
    public static synchronized void forget(IsoGameCharacter body) {
        clear(body); STATES.remove(body); SAOWorldSoundPulses.forget(body);
    }
    public static synchronized void resetRuntimeForWorld() {
        for (var entry : STATES.entrySet()) stop(entry.getKey(), entry.getValue(), "world-reset");
        STATES.clear();
    }
    /** Detached primitives; inspection never performs admission or animation work. */
    public static synchronized KahluaTable state(IsoGameCharacter body) {
        KahluaTable out = LuaManager.platform.newTable(); State state = STATES.get(body);
        out.rawset("active", state != null && state.active);
        out.rawset("mode", state == null ? "none" : state.mode);
        out.rawset("cueId", state == null ? "" : state.cue);
        out.rawset("actionId", state == null ? "" : state.action);
        out.rawset("phase", state == null ? "idle" : state.phase);
        out.rawset("reason", SAOOrientationAnimation.readFailure() != null
            ? SAOOrientationAnimation.readFailure() : state == null ? "idle" : state.reason);
        out.rawset("remainingSeconds", state == null || !state.active ? 0.0 : (double)Math.max(0, DURATION-state.elapsed));
        out.rawset("readiness", state == null ? 0.0 : (double)state.readiness);
        out.rawset("steadiness", state == null ? 0.0 : (double)state.steadiness);
        out.rawset("allowBodyTurn", state != null && state.bodyTurn);
        out.rawset("layerReady", state != null && state.layerReady);
        out.rawset("headHorizontal", state == null ? 0.0 : (double)state.horizontal);
        out.rawset("requiredSeconds", state == null ? 0.0 : (double)state.required);
        out.rawset("maintainedSeconds", state == null ? 0.0 : (double)state.maintained);
        Vector2 gaze = SAOSenses.gaze(body, new Vector2());
        out.rawset("gazeX", Float.isFinite(gaze.x) ? (double)gaze.x : 0.0);
        out.rawset("gazeY", Float.isFinite(gaze.y) ? (double)gaze.y : 0.0);
        return out;
    }
}
