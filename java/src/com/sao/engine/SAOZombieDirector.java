package com.sao.engine;

import com.sao.agent.SAOAgent;
import java.lang.reflect.Field;
import java.lang.reflect.Method;
import zombie.ai.State;
import zombie.ai.states.AttackState;
import zombie.characters.IsoZombie;

/**
 * Incoming combat: makes vanilla zombies genuinely fight an off-slot body.
 * Typed port of the reference acquisition bridge. An off-slot shell runs no
 * local-player LOS updates, so zombie perception starves without this:
 * the target vector and last-seen tiles are mirrored manually, seen-time gets
 * a floor (the bite animation gates on > 0.5s), and attack entry goes through
 * BOTH engine layers — the legacy AttackState for the collision/damage
 * callback and the action-context attack state for the animation graph.
 * Vanilla getShouldAttack() remains the authority throughout.
 */
public final class SAOZombieDirector {

    private static final float VANILLA_BITE_COLLISION_RANGE = 1.0f;
    private static final float STANDING_ATTACK_VECTOR_RANGE = 0.70f;
    private static final float MINIMUM_ATTACK_SEEN_TIME = 0.55f;
    private static final float ATTACK_VISIBILITY_ENVELOPE = 1.25f;

    private static Field canSeeTargetField;
    private static Method shouldAttackMethod;

    private SAOZombieDirector() {
    }

    public static String direct(IsoZombie zombie, SAOIsoPlayerShell shell) {
        if (SAOKnox.isKnoxHuman(zombie)) {
            return "REFUSED_KNOX_HUMAN";
        }
        try {
            if (zombie.getTarget() != shell) {
                // Acquisition only; already-targeted zombies stay vanilla.
                shell.setZombiesDontAttack(false);
                zombie.setUseless(false);
                zombie.setCanWalk(true);
                zombie.spotted(shell, true);
                zombie.setTarget(shell);
                refreshTargetVector(zombie, shell);
                zombie.pathToCharacter(shell);
                return "ZOMBIE_DIRECTED status="
                    + (zombie.getTarget() == shell ? "acquired" : "rejected");
            }

            float distance = refreshTargetVector(zombie, shell);
            zombie.setTarget(shell);
            if (distance <= ATTACK_VISIBILITY_ENVELOPE) {
                supplyOffSlotAttackVisibility(zombie);
            }
            String action = String.valueOf(zombie.getCurrentActionContextStateName());
            if (zombie.isZombieAttacking(shell) || "attack".equalsIgnoreCase(action)) {
                return "ZOMBIE_DIRECTED status=attacking distance=" + distance;
            }
            if (!canEnterAttackFrom(action)) {
                // Never replace hit reactions, falls, climbs or get-ups.
                return "ZOMBIE_DIRECTED status=attack-deferred action=" + action;
            }
            if (distance <= VANILLA_BITE_COLLISION_RANGE) {
                clampAttackVector(zombie, STANDING_ATTACK_VECTOR_RANGE);
            }
            if (vanillaShouldAttack(zombie)) {
                if (zombie.getTargetSeenTime() < MINIMUM_ATTACK_SEEN_TIME) {
                    return "ZOMBIE_DIRECTED status=attack-windup distance=" + distance;
                }
                zombie.clearVariable("AttackDidDamage");
                zombie.clearVariable("ZombieBiteDone");
                zombie.setAttackOutcome("start");
                enterVanillaAttack(zombie);
                return "ZOMBIE_DIRECTED status=attack-transition previous=" + action;
            }
            zombie.spotted(shell, true);
            zombie.setTarget(shell);
            zombie.pathToCharacter(shell);
            return "ZOMBIE_DIRECTED status=pursuing distance=" + distance;
        } catch (Throwable throwable) {
            SAOAgent.log("zombie director threw: " + throwable);
            return "ZOMBIE_DIRECT_FAILED " + throwable;
        }
    }

    // ------------------------------------------------------------------

    private static float refreshTargetVector(IsoZombie zombie, SAOIsoPlayerShell shell) {
        float dx = shell.getX() - zombie.getX();
        float dy = shell.getY() - zombie.getY();
        zombie.vectorToTarget.x = dx;
        zombie.vectorToTarget.y = dy;
        zombie.lastTargetSeenX = (int) Math.floor(shell.getX());
        zombie.lastTargetSeenY = (int) Math.floor(shell.getY());
        zombie.lastTargetSeenZ = (int) Math.floor(shell.getZ());
        return (float) Math.sqrt(dx * dx + dy * dy);
    }

    private static void clampAttackVector(IsoZombie zombie, float maximumLength) {
        float x = zombie.vectorToTarget.x;
        float y = zombie.vectorToTarget.y;
        float length = (float) Math.sqrt(x * x + y * y);
        if (length <= maximumLength || length <= 0.001f) {
            return;
        }
        float scale = maximumLength / length;
        zombie.vectorToTarget.x = x * scale;
        zombie.vectorToTarget.y = y * scale;
    }

    private static void supplyOffSlotAttackVisibility(IsoZombie zombie) throws Exception {
        if (canSeeTargetField == null) {
            canSeeTargetField = findField(zombie.getClass(), "canSeeTarget");
            canSeeTargetField.setAccessible(true);
        }
        canSeeTargetField.setBoolean(zombie, true);
        if (zombie.getTargetSeenTime() < MINIMUM_ATTACK_SEEN_TIME) {
            zombie.setTargetSeenTime(MINIMUM_ATTACK_SEEN_TIME);
        }
    }

    private static boolean vanillaShouldAttack(IsoZombie zombie) throws Exception {
        if (shouldAttackMethod == null) {
            shouldAttackMethod = IsoZombie.class.getDeclaredMethod("getShouldAttack");
            shouldAttackMethod.setAccessible(true);
        }
        return (Boolean) shouldAttackMethod.invoke(zombie);
    }

    private static boolean canEnterAttackFrom(String action) {
        if (action == null) {
            return false;
        }
        return switch (action.toLowerCase(java.util.Locale.ROOT)) {
            case "idle", "lunge", "walktoward", "pathfind", "turnalerted" -> true;
            default -> false;
        };
    }

    private static void enterVanillaAttack(IsoZombie zombie) {
        // Both layers, or the bite arms without ever reaching the damage event.
        zombie.changeState((State) AttackState.instance());
        var context = zombie.getActionContext();
        var group = context.getGroup();
        var attack = group.findState("attack");
        if (attack != null) {
            context.setCurrentState(attack);
        }
    }

    private static Field findField(Class<?> type, String name) throws NoSuchFieldException {
        for (Class<?> current = type; current != null; current = current.getSuperclass()) {
            try {
                return current.getDeclaredField(name);
            } catch (NoSuchFieldException ignored) {
                // climb
            }
        }
        throw new NoSuchFieldException(type.getName() + "." + name);
    }
}
