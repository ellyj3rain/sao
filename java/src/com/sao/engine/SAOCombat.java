package com.sao.engine;

import com.sao.agent.SAOAgent;
import com.sao.agent.SAOCombatGate;
import zombie.ai.states.SwipeStatePlayer;
import zombie.characters.IsoGameCharacter;
import zombie.characters.IsoZombie;
import zombie.inventory.types.HandWeapon;
import zombie.iso.IsoGridSquare;

/**
 * One controlled melee encounter through IsoPlayer's normal attack entry —
 * typed port of the reference combat controller. The swing is pressedAttack(),
 * the same entry a player presses; verdicts are evidence-based (SUCCEEDED
 * requires observed damage, not merely a dead target); hit reactions own the
 * body between swings; a defense window is yielded after every swing in live
 * combat, with AttackType cleared so a frontal zombie collision can still
 * apply damage.
 */
public final class SAOCombat {

    private static final int ATTACK_RETRY_TICKS = 30;
    private static final int AIM_SETTLE_TICKS = 18;
    private static final int DIRECT_STATE_FALLBACK_TICKS = 3;
    private static final int ATTACK_RECOVERY_TICKS = 24;
    private static final float REAPPROACH_BUFFER = 0.20f;
    private static final int LIVE_PURSUIT_REFRESH_TICKS = 6;

    private SAOIsoPlayerShell shell;
    private IsoGameCharacter target;
    private String phase = "IDLE";
    private int ticks;
    private int lastAttackTick = -ATTACK_RETRY_TICKS;
    private int lastReapproachTick = -LIVE_PURSUIT_REFRESH_TICKS;
    private int attackRequests;
    private float lastTargetHealth;
    private float weaponMaxRange;
    private float desiredAttackRange;
    private boolean damageObserved;
    private boolean attackAnimationObserved;
    private int aimTicks;
    private boolean directStateFallbackUsed;
    private boolean attackCycleActive;
    private boolean liveCombat;
    private int defenseWindowUntil;
    private boolean rangedMode;

    public String begin(SAOIsoPlayerShell activeShell, IsoGameCharacter combatTarget,
                        boolean live) {
        reset();
        if (activeShell == null || combatTarget == null) {
            return "COMBAT_FAILED INVALID_TARGET";
        }
        shell = activeShell;
        target = combatTarget;
        liveCombat = live;

        // Force class load so the transformer has fired (or not) decisively.
        SwipeStatePlayer.instance();
        if (!SAOCombatGate.isPatchReady()) {
            reset();
            return "COMBAT_FAILED CALLBACK_PATCH_NOT_READY calls="
                + SAOCombatGate.getPatchedCallCount();
        }
        if (!(shell.getPrimaryHandItem() instanceof HandWeapon weapon)) {
            reset();
            return "COMBAT_FAILED NO_EQUIPPED_WEAPON";
        }
        rangedMode = weapon.isRanged();
        if (rangedMode && ammoCount(weapon) <= 0) {
            reset();
            return "COMBAT_FAILED NO_AMMO";
        }

        // Combat always interrupts rest posture.
        shell.setSitOnGround(false);
        shell.setSittingOnFurniture(false);
        shell.setOnFloor(false);
        shell.setVariable("forceGetUp", true);

        weaponMaxRange = weapon.getMaxRange();
        if (rangedMode) {
            // Fire from usable range, not the muzzle pressed to the chest
            // and not the far edge where spread wastes the shot.
            desiredAttackRange = Math.min(Math.max(2.0f, weaponMaxRange * 0.6f), 7.0f);
        } else {
            desiredAttackRange = Math.max(0.50f, weaponMaxRange - 0.40f);
        }
        lastTargetHealth = target.getHealth();

        shell.setZombiesDontAttack(false);
        if (target instanceof IsoZombie zombieTarget) {
            zombieTarget.setCanWalk(true);
            zombieTarget.setUseless(false);
        }

        SAOMovement.clearIntent(shell);
        shell.pathToCharacter(target);
        shell.setRunning(true);
        phase = "APPROACHING";
        return "COMBAT_STARTED mode=" + (live ? "live" : "gate")
            + " targetHealth=" + lastTargetHealth
            + " maxRange=" + weaponMaxRange
            + " desiredRange=" + desiredAttackRange;
    }

    public String tick() {
        if (shell == null || target == null) {
            return "COMBAT_IDLE";
        }
        ticks++;
        float currentHealth = target.getHealth();
        if (currentHealth < lastTargetHealth) {
            damageObserved = true;
            SAOAgent.log("combat DAMAGE targetHealth=" + currentHealth);
        }
        lastTargetHealth = currentHealth;

        if (target.isDead()) {
            clearAttackIntent();
            if (attackRequests == 0 || !damageObserved) {
                phase = "FAILED";
                return "COMBAT_FAILED TARGET_DIED_WITHOUT_NPC_DAMAGE attacks=" + attackRequests;
            }
            phase = "SUCCEEDED";
            return "COMBAT_SUCCEEDED attacks=" + attackRequests
                + " damageObserved=true targetHealth=" + currentHealth;
        }

        // The kill outranks the empty magazine: a last-round kill is a
        // SUCCESS, not an ammo failure ([A12] find - order matters).
        if (rangedMode
            && shell.getPrimaryHandItem() instanceof HandWeapon liveWeapon
            && ammoCount(liveWeapon) <= 0) {
            clearAttackIntent();
            phase = "FAILED";
            return "COMBAT_FAILED OUT_OF_AMMO attacks=" + attackRequests
                + (damageObserved ? " damageObserved=true" : "");
        }

        float dx = target.getX() - shell.getX();
        float dy = target.getY() - shell.getY();
        float targetDistance = (float) Math.sqrt(dx * dx + dy * dy);
        float reapproachThreshold = desiredAttackRange + REAPPROACH_BUFFER;

        String bodyAction = String.valueOf(shell.getCurrentActionContextStateName());
        if (liveCombat && bodyAction.toLowerCase(java.util.Locale.ROOT).contains("hitreaction")) {
            // The vanilla hit reaction owns the body until its graph exits.
            clearAttackIntent();
            shell.clearVariable("AttackType");
            attackCycleActive = false;
            lastAttackTick = ticks;
            defenseWindowUntil = Math.max(defenseWindowUntil, ticks + ATTACK_RECOVERY_TICKS);
            return "COMBAT_REACTING action=" + bodyAction;
        }

        if ("APPROACHING".equals(phase)) {
            if (targetDistance > reapproachThreshold) {
                if (ticks - lastReapproachTick >= LIVE_PURSUIT_REFRESH_TICKS) {
                    shell.pathToCharacter(target);
                    shell.setRunning(true);
                    lastReapproachTick = ticks;
                }
                return "COMBAT_APPROACHING distance=" + targetDistance;
            }
            phase = "AIMING";
            aimTicks = 0;
            shell.getPathFindBehavior2().cancel();
            SAOMovement.clearIntent(shell);
        }

        if (targetDistance > reapproachThreshold
            && !shell.isAttacking() && !shell.isPerformingAttackAnimation()) {
            clearAttackIntent();
            shell.pathToCharacter(target);
            shell.setRunning(true);
            phase = "APPROACHING";
            aimTicks = 0;
            lastReapproachTick = ticks;
            return "COMBAT_REAPPROACHING distance=" + targetDistance;
        }

        IsoGridSquare targetSquare = target.getCurrentSquare();
        if (targetSquare != null) {
            shell.setAttackTargetSquare(targetSquare);
        }

        boolean attackStarted = shell.isAttackStarted();
        boolean attacking = shell.isAttacking();
        boolean attackAnimation = shell.isPerformingAttackAnimation();
        boolean attackActive = attackStarted || attacking || attackAnimation;
        if (attackCycleActive && !attackActive) {
            lastAttackTick = ticks;
            attackCycleActive = false;
            if (liveCombat) {
                clearAttackIntent();
                shell.clearVariable("AttackType");
                defenseWindowUntil = ticks + ATTACK_RECOVERY_TICKS;
                return "COMBAT_RECOVERING ticks=" + ATTACK_RECOVERY_TICKS;
            }
        } else {
            attackCycleActive = attackActive;
        }
        if (liveCombat && ticks < defenseWindowUntil) {
            return "COMBAT_RECOVERING ticks=" + (defenseWindowUntil - ticks);
        }

        boolean targetOnFloor = target.isOnFloor();
        faceTarget();
        applyCombatStance(false, targetOnFloor);

        if ("AIMING".equals(phase)) {
            aimTicks++;
            if (aimTicks < AIM_SETTLE_TICKS) {
                return "COMBAT_AIMING ticks=" + aimTicks + "/" + AIM_SETTLE_TICKS;
            }
            phase = "ATTACKING";
        }

        attackAnimationObserved = attackAnimationObserved || attackAnimation;
        if (attackAnimation) {
            shell.setInitiateAttack(false);
            setAiAttackIntent(true, false);
        }
        if (attackRequests > 0 && !attackAnimationObserved && !damageObserved) {
            setAiAttackIntent(true, true);
            shell.setInitiateAttack(true);
        }
        if (attackRequests > 0
            && !directStateFallbackUsed
            && !attackAnimationObserved
            && ticks - lastAttackTick >= DIRECT_STATE_FALLBACK_TICKS
            && "idle".equalsIgnoreCase(bodyAction)) {
            shell.changeState(SwipeStatePlayer.instance());
            shell.setAttackStarted(true);
            shell.setInitiateAttack(true);
            setAiAttackIntent(true, true);
            directStateFallbackUsed = true;
            SAOAgent.log("combat DIRECT_SWIPE_STATE_FALLBACK");
        }

        String attackType = String.valueOf(shell.getAttackType());
        boolean attackTypeClear = attackType.isEmpty()
            || "null".equalsIgnoreCase(attackType) || "NONE".equalsIgnoreCase(attackType);
        if (!attackStarted && !attacking && shell.isWeaponReady() && attackTypeClear
            && ticks - lastAttackTick >= ATTACK_RETRY_TICKS) {
            requestAttack(targetOnFloor);
            attackRequests++;
            lastAttackTick = ticks;
            attackAnimationObserved = false;
            directStateFallbackUsed = false;
            SAOAgent.log("combat ATTACK_REQUEST count=" + attackRequests
                + " targetHealth=" + currentHealth);
        }
        return "COMBAT_ATTACKING attacks=" + attackRequests
            + " animation=" + attackAnimation
            + " damage=" + damageObserved
            + " targetHealth=" + currentHealth;
    }

    /** Rounds available in this weapon, chamber included; -1 unknown.
     * [A24]: the reflective lookup dated from when the getter was not
     * statically reachable; on 42.20.4 it is public on InventoryItem
     * (verified by javap - it MOVED UP a class, which is also why it
     * vanished from HandWeapon's own method list). Direct call now;
     * the -1 unknown convention stays for the catch path. */
    public static int ammoCount(HandWeapon weapon) {
        try {
            return weapon.getCurrentAmmoCount();
        } catch (Throwable throwable) {
            return -1;
        }
    }

    public void reset() {
        if (shell != null) {
            try {
                clearAttackIntent();
            } catch (Throwable ignored) {
                // teardown continues
            }
        }
        shell = null;
        target = null;
        phase = "IDLE";
        ticks = 0;
        lastAttackTick = -ATTACK_RETRY_TICKS;
        lastReapproachTick = -LIVE_PURSUIT_REFRESH_TICKS;
        attackRequests = 0;
        lastTargetHealth = 0.0f;
        weaponMaxRange = 0.0f;
        desiredAttackRange = 0.0f;
        damageObserved = false;
        attackAnimationObserved = false;
        aimTicks = 0;
        directStateFallbackUsed = false;
        attackCycleActive = false;
        liveCombat = false;
        defenseWindowUntil = 0;
        rangedMode = false;
    }

    public String phase() {
        return phase;
    }

    // ------------------------------------------------------------------

    private void clearAttackIntent() {
        shell.setIsAiming(false);
        shell.setAuthorizeMeleeAction(false);
        shell.setAuthorizeShoveStomp(false);
        shell.setInitiateAttack(false);
        shell.setAttackStarted(false);
        shell.setAimAtFloor(false);
        shell.isCharging = false;
        shell.useChargeDelta = 0.0f;
        shell.clearHandToHandAttack();
        setAiAttackIntent(false, false);
    }

    private void applyCombatStance(boolean initiate, boolean aimAtFloor) {
        shell.setBannedAttacking(false);
        shell.setAuthorizeMeleeAction(true);
        shell.setAuthorizeShoveStomp(aimAtFloor);
        shell.setAimAtFloor(aimAtFloor);
        shell.setIsAiming(true);
        shell.isCharging = true;
        setAiAttackIntent(true, initiate);
    }

    private void requestAttack(boolean aimAtFloor) {
        shell.clearHandToHandAttack();
        shell.setAimAtFloor(aimAtFloor);
        shell.useChargeDelta = 36.0f;
        applyCombatStance(false, aimAtFloor);
        shell.pressedAttack();
        shell.setAttackStarted(true);
        shell.setInitiateAttack(true);
        setAiAttackIntent(true, true);
    }

    private void setAiAttackIntent(boolean aiming, boolean initiate) {
        var ai = shell.getECSComponent(zombie.characters.component.AIComponent.class);
        if (ai == null) {
            return;
        }
        var vars = ai.getHumanControlVars();
        if (vars == null) {
            return;
        }
        vars.aiming = aiming;
        vars.melee = false;
        vars.bannedAttacking = false;
        vars.initiateAttack = initiate;
    }

    private void faceTarget() {
        float dx = target.getX() - shell.getX();
        float dy = target.getY() - shell.getY();
        float length = (float) Math.sqrt(dx * dx + dy * dy);
        if (length <= 0.001f) {
            return;
        }
        dx /= length;
        dy /= length;
        shell.setTargetAndCurrentDirection(dx, dy);
        shell.setForwardDirection(dx, dy);
        shell.setDirectionAngle((float) Math.toDegrees(Math.atan2(dy, dx)));
    }
}
