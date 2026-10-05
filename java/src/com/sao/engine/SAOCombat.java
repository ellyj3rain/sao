package com.sao.engine;

import com.sao.agent.SAOAgent;
import com.sao.agent.SAOCombatGate;
import zombie.ai.states.SwipeStatePlayer;
import zombie.characters.IsoGameCharacter;
import zombie.characters.IsoZombie;
import zombie.inventory.types.HandWeapon;
import zombie.iso.IsoGridSquare;
import zombie.iso.LosUtil;
import zombie.inventory.InventoryItem;
import java.util.Objects;

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

    // One actor-owned request, separate from the older encounter/gate driver.
    private boolean bounded;
    private String observedKind, observedKey, observedMode, actorId, terminal;
    private Object actorToken;
    private InventoryItem observedWeapon;
    private boolean cancelRequested, requested, nativeCycleSeen, priorHandToHand;
    private int startTicks;
    private static final int NATIVE_START_LIMIT = 120;

    private record Opportunity(IsoGameCharacter target, String mode, float distance,
                               float reach, String refusal) {
        String text() {
            return refusal != null ? "REFUSED\t" + refusal
                : "AVAILABLE\t" + mode + "\t" + distance + "\t" + reach;
        }
    }

    private static Opportunity refused(String reason) {
        return new Opportunity(null, null, 0, 0, reason);
    }

    /** Capability only. Disposition and Standing remain the calling person's owners. */
    public static String opportunity(SAOIsoPlayerShell body, String kind, String key) {
        return assess(body, kind, key, null).text();
    }

    private static Opportunity assess(SAOIsoPlayerShell body, String kind, String key, String mode) {
        if (SAOConceptObservation.actor(body) == null) return refused("body-unavailable");
        IsoGameCharacter other = SAOPerceptionScanner.observedCombatTarget(body, kind, key);
        if (other == null) return refused("target-not-observed-now");
        if (!zombie.CombatManager.checkPVP(body, other, false)) return refused("native-pvp");
        IsoGridSquare from = body.getCurrentSquare(), to = other.getCurrentSquare();
        if (from == null || to == null || from.getZ() != to.getZ()) return refused("floor");
        var line = LosUtil.lineClear(body.getCell(), from.getX(), from.getY(), from.getZ(),
            to.getX(), to.getY(), to.getZ(), false);
        if (line != LosUtil.TestResults.Clear && line != LosUtil.TestResults.ClearThroughOpenDoor)
            return refused("obstructed");
        float dx = other.getX() - body.getX(), dy = other.getY() - body.getY();
        float distance = (float)Math.sqrt(dx * dx + dy * dy);
        if (!Float.isFinite(distance)) return refused("invalid-distance");
        HandWeapon held = body.getPrimaryHandItem() instanceof HandWeapon value ? value : null;
        float shoveReach = body.bareHands == null ? 0 : body.bareHands.getMaxRange(body);
        boolean shove = shoveReach > 0 && distance <= shoveReach && body.canPerformHandToHandCombat()
            && !other.isOnFloor() && !SAOPerceptionScanner.isProneOrCrawling(other);
        // CombatManager.calculateAttackVars uses a strict .6 prone hand-to-hand
        // range. Native targetOnGround/aimAtFloor are checked after admission too.
        float stompReach = Math.min(shoveReach, .6f);
        boolean stomp = stompReach > 0 && distance < stompReach && body.canPerformHandToHandCombat()
            && (other.isOnFloor() || SAOPerceptionScanner.isProneOrCrawling(other));
        boolean weapon = held != null && !held.isBroken();
        float reach = weapon ? held.getMaxRange(body) : 0;
        boolean inRange = Float.isFinite(reach) && reach > 0 && distance <= reach;
        boolean ranged = weapon && held.isRanged() && !held.isJammed()
            && (held.haveChamber() ? held.isRoundChambered() && !held.isSpentRoundChambered()
                : held.getCurrentAmmoCount() >= Math.max(1, held.getAmmoPerShoot()))
            && distance >= held.getMinRangeRanged() && inRange;
        boolean melee = weapon && SAOEquipment.meleeScore(held) != Float.NEGATIVE_INFINITY && inRange;
        if (mode == null) mode = ranged ? "ranged" : melee ? "melee" : stomp ? "stomp" : shove ? "shove" : null;
        boolean available = "shove".equals(mode) ? shove : "melee".equals(mode) ? melee
            : "stomp".equals(mode) ? stomp : "ranged".equals(mode) && ranged;
        if (!available) return refused("no-physical-" + (mode == null ? "action" : mode));
        return new Opportunity(other, mode, distance, "shove".equals(mode) ? shoveReach
            : "stomp".equals(mode) ? stompReach : reach, null);
    }

    /** Adjacent observed candidates only; a MOVE row is not a safe-route promise. */
    public static String localMoves(SAOIsoPlayerShell body) {
        if (SAOConceptObservation.actor(body) == null) return "REFUSED\tbody-unavailable";
        IsoGridSquare from = body.getCurrentSquare();
        StringBuilder result = new StringBuilder();
        for (int dx = -1; dx <= 1; dx++) for (int dy = -1; dy <= 1; dy++) {
            if (dx == 0 && dy == 0) continue;
            IsoGridSquare next = body.getCell().getGridSquare(from.getX() + dx, from.getY() + dy, from.getZ());
            if (!SAOPerceptionScanner.canSeeWorldSquareNow(body, next, 3)
                    || !next.isSolidFloor() || next.isSolid() || next.isSolidTrans()
                    || next.HasStairs() || next.HasStairsBelow() || !next.isFree(false)
                    || from.isBlockedTo(next)) continue;
            boolean occupied = false;
            for (var moving : next.getMovingObjects())
                if (moving instanceof IsoGameCharacter && moving != body) { occupied = true; break; }
            if (occupied) continue;
            if (result.length() > 0) result.append('\n');
            result.append("MOVE\t").append(next.getX() + .5f).append('\t')
                .append(next.getY() + .5f).append('\t').append(next.getZ());
        }
        return result.toString();
    }

    public boolean isBounded() { return bounded; }
    public boolean hasCommitment() {
        return shell != null && (bounded ? terminal == null
            : !("IDLE".equals(phase) || "FAILED".equals(phase) || "SUCCEEDED".equals(phase)));
    }

    public String beginObserved(SAOIsoPlayerShell body, String kind, String key, String mode) {
        if (hasCommitment()) return "COMBAT_FAILED BODY_COMMITTED";
        Opportunity offer = assess(body, kind, key, mode);
        if (mode == null || offer.refusal != null)
            return "COMBAT_FAILED " + (offer.refusal == null ? "invalid-mode" : offer.refusal);
        if (nativeOwnsBody(body) || body.isAttackStarted() || body.isAttacking()
                || unavailablePosture(body)) return "COMBAT_FAILED NATIVE_BODY_BUSY";
        SwipeStatePlayer.instance();
        if (!SAOCombatGate.isPatchReady()) return "COMBAT_FAILED CALLBACK_PATCH_NOT_READY";
        reset();
        bounded = true; shell = body; target = offer.target;
        actorId = SAOConceptObservation.actor(body); actorToken = body.getModData().rawget("SAOExternalToken");
        observedKind = kind; observedKey = key; observedMode = mode; observedWeapon = body.getPrimaryHandItem();
        priorHandToHand = body.isAuthorizedHandToHand();
        phase = "OBSERVED_READY";
        return "COMBAT_STARTED mode=" + mode + " bounded=true";
    }

    private static boolean unavailablePosture(SAOIsoPlayerShell body) {
        var current = body.getCurrentState();
        return body.isOnFloor() || body.isSitOnGround() || body.isSittingOnFurniture()
            || body.isOnBed() || body.isClimbing() || body.isBeingGrappled()
            || body.getVehicle() != null || body.hasPath() || body.playerMoveDir.getLengthSquared() > .0001f
            || current == zombie.ai.states.ClimbOverFenceState.instance()
            || current == zombie.ai.states.ClimbThroughWindowState.instance()
            || current == zombie.ai.states.ClimbOverWallState.instance()
            || body.getActionContext().hasEventOccurred("EventClimbFence")
            || body.getActionContext().hasEventOccurred("EventClimbWindow")
            || !body.getCharacterActions().isEmpty();
    }

    private static boolean attackOwnsBody(SAOIsoPlayerShell body) {
        String state = String.valueOf(body.getCurrentActionContextStateName()).toLowerCase(java.util.Locale.ROOT);
        return body.isPerformingAttackAnimation() || body.isPerformingShoveAnimation() || body.isPerformingStompAnimation()
            || body.getCurrentState() == SwipeStatePlayer.instance()
            || state.contains("attack") || state.contains("shove") || state.contains("stomp");
    }

    private static boolean nativeOwnsBody(SAOIsoPlayerShell body) {
        String state = String.valueOf(body.getCurrentActionContextStateName()).toLowerCase(java.util.Locale.ROOT);
        return attackOwnsBody(body) || state.contains("hitreaction") || body.isBeingGrappled()
            || body.getCurrentState() == zombie.ai.states.PlayerHitReactionState.instance()
            || body.getCurrentState() == zombie.ai.states.PlayerHitReactionPVPState.instance();
    }

    private boolean sameOwner() {
        return actorId != null && actorId.equals(SAOConceptObservation.actor(shell))
            && Objects.equals(actorToken, shell.getModData().rawget("SAOExternalToken"));
    }

    public String cancelObserved() {
        if (!bounded || terminal != null) return "COMBAT_CANCELLED";
        cancelRequested = true;
        return "COMBAT_HELD".equals(tickObserved()) ? "COMBAT_HELD" : "COMBAT_CANCELLED";
    }

    private String finishObserved(String result) {
        if (sameOwner()) {
            clearAttackIntent();
            shell.setDoShove(false);
            shell.setAuthorizedHandToHand(priorHandToHand);
            shell.clearVariable("AttackType");
        }
        terminal = result; phase = "OBSERVED_DONE";
        return result;
    }

    private String tickObserved() {
        if (terminal != null) return terminal;
        if (!sameOwner()) {
            terminal = "COMBAT_FAILED BODY_OWNER_CHANGED";
            return terminal; // A successor owner is never cleaned up by this commitment.
        }
        if (nativeOwnsBody(shell)) {
            if (requested && attackOwnsBody(shell)) {
                nativeCycleSeen = true;
                shell.setInitiateAttack(false);
                setAiAttackIntent(true, false);
            }
            return "COMBAT_HELD";
        }
        if (cancelRequested) return finishObserved("COMBAT_CANCELLED");
        if (nativeCycleSeen) return finishObserved("COMBAT_COMPLETED attempt=1 outcome=unattributed");
        if (requested) {
            if (++startTicks >= NATIVE_START_LIMIT) return finishObserved("COMBAT_FAILED NO_NATIVE_START");
            return "COMBAT_PENDING";
        }
        Opportunity fresh = assess(shell, observedKind, observedKey, observedMode);
        if (fresh.refusal != null || fresh.target != target || shell.getPrimaryHandItem() != observedWeapon
                || unavailablePosture(shell)) return finishObserved("COMBAT_FAILED ADMISSION_CHANGED");
        faceTarget();
        shell.setAttackTargetSquare(target.getCurrentSquare());
        boolean shove = "shove".equals(observedMode);
        boolean stomp = "stomp".equals(observedMode);
        boolean handToHand = shove || stomp;
        boolean floor = stomp || !shove && (target.isOnFloor() || SAOPerceptionScanner.isProneOrCrawling(target));
        applyCombatStance(false, floor);
        if (!handToHand && (++aimTicks < AIM_SETTLE_TICKS || !shell.isWeaponReady())) {
            if (aimTicks >= NATIVE_START_LIMIT) return finishObserved("COMBAT_FAILED WEAPON_NOT_READY");
            return "COMBAT_AIMING ticks=" + aimTicks;
        }
        shell.setAuthorizeShoveStomp(handToHand || floor);
        shell.setAuthorizedHandToHand(handToHand || priorHandToHand);
        shell.setDoShove(handToHand);
        shell.useChargeDelta = 36.0f;
        requested = true;
        try {
            shell.pressedAttack();
        } catch (Throwable error) {
            SAOAgent.log("observed combat request threw: " + error);
            cancelRequested = true;
            return nativeOwnsBody(shell) ? "COMBAT_HELD" : finishObserved("COMBAT_FAILED NATIVE_REQUEST_ERROR");
        }
        // pressedAttack owns admission. Do not fabricate its acceptance flags.
        if (!shell.isAttackStarted() && !shell.isInitiateAttack())
            return finishObserved("COMBAT_FAILED NATIVE_REFUSED");
        if (stomp && (!shell.isDoStomp() || shell.targetOnGround != target))
            return finishObserved("COMBAT_FAILED NATIVE_STOMP_TARGET_NOT_ADMITTED");
        setAiAttackIntent(true, true);
        phase = "OBSERVED_REQUESTED";
        return "COMBAT_PENDING";
    }

    public String begin(SAOIsoPlayerShell activeShell, IsoGameCharacter combatTarget,
                        boolean live) {
        if (bounded && hasCommitment()) return "COMBAT_FAILED BODY_COMMITTED";
        reset();
        if (activeShell == null || combatTarget == null) {
            return "COMBAT_FAILED INVALID_TARGET";
        }
        if (isInactiveTarget(combatTarget)) {
            return "COMBAT_FAILED TARGET_INACTIVE";
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
            try {
                if (!zombieTarget.isUseless()) {
                    zombieTarget.setUseless(false);
                }
            } catch (Throwable ignored) {
            }
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
        if (bounded) return tickObserved();
        if (shell == null || target == null) {
            return "COMBAT_IDLE";
        }
        // [C60] Optional stealth/debug controllers may deactivate a zombie
        // after acquisition. Revalidate here, where the attack is consumed;
        // the scanner and nearest-target lookup cannot protect a held target.
        if (isInactiveTarget(target)) {
            clearAttackIntent();
            phase = "FAILED";
            return "COMBAT_FAILED TARGET_INACTIVE";
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

        // [C124] Ground targeting: crawler zombies, tripping/knocked-down bodies,
        // and mod-authored prone/crawling targets are attacked at the floor.
        boolean targetOnFloor = target.isOnFloor()
            || (target instanceof IsoZombie z && z.isCrawling())
            || SAOPerceptionScanner.isProneOrCrawling(target);
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

    private static boolean isInactiveTarget(IsoGameCharacter candidate) {
        if (candidate instanceof IsoZombie zombie) {
            try {
                return zombie.isUseless();
            } catch (Throwable ignored) {
                // An absent optional state cannot manufacture deactivation;
                // the ordinary target contract remains authoritative.
            }
        }
        return false;
    }

    public void reset() {
        if (bounded && terminal == null) {
            cancelObserved();
            if (terminal == null) return;
        }
        boolean clearLegacy = !bounded;
        if (shell != null && clearLegacy) {
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
        bounded = false; observedKind = null; observedKey = null; observedMode = null;
        actorId = null; actorToken = null; observedWeapon = null; terminal = null;
        cancelRequested = false; requested = false; nativeCycleSeen = false;
        priorHandToHand = false; startTicks = 0;
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
