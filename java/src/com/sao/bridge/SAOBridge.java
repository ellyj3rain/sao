package com.sao.bridge;

import com.sao.agent.SAOAgent;
import com.sao.engine.SAOIsoPlayerShell;
import com.sao.engine.SAOMovement;
import com.sao.engine.SAORouteState;
import java.util.Map;
import java.util.WeakHashMap;
import zombie.characters.IsoGameCharacter;
import zombie.characters.IsoPlayer;
import zombie.characters.SurvivorDesc;
import zombie.characters.SurvivorFactory;
import zombie.characters.component.AIComponent;
import zombie.characters.ecs.ECSComponent;
import zombie.core.skinnedmodel.ModelManager;
import zombie.iso.IsoCell;
import zombie.iso.IsoGridSquare;
import zombie.iso.IsoWorld;

/**
 * The object Lua sees as the global SAOJavaBridge. Instance methods only —
 * Kahlua calls them as SAOJavaBridge:method(...). Every method is exception-
 * safe: a Java throw into Kahlua would take down the calling Lua frame, so
 * failures return null/false and log to SAOAgent.log instead.
 *
 * The spawn sequence is the full verified NPC-body contract: construct the
 * shell, flag it, give it an off-slot playerIndex (index 0 owns the system
 * cursor), place it on its square, insert it into the cell's moving objects,
 * register it with ModelManager (without which nothing draws), verify the
 * local-player slots were not disturbed, and zero all movement intent
 * (uninitialized intent is what made an early body wander on its own).
 */
public final class SAOBridge {

    public static final SAOBridge INSTANCE = new SAOBridge();

    private final Map<SAOIsoPlayerShell, SAORouteState> routes = new WeakHashMap<>();
    private final Map<SAOIsoPlayerShell, com.sao.engine.SAOCombat> combats = new WeakHashMap<>();

    /** Combat verbs (typed transplant; gated on the melee-callback patch). */
    public String beginCombatNearest(Object object, boolean live) {
        try {
            if (!(object instanceof SAOIsoPlayerShell shell)) {
                return "NOT_A_SHELL";
            }
            zombie.iso.IsoCell cell = shell.getCell();
            if (cell == null) {
                return "COMBAT_FAILED NO_CELL";
            }
            zombie.characters.IsoZombie nearest = null;
            float best = Float.MAX_VALUE;
            var zombies = cell.getZombieList();
            for (int index = 0; index < zombies.size(); index++) {
                var zombie = zombies.get(index);
                if (zombie == null || zombie.isDead()
                    || com.sao.engine.SAOKnox.isKnoxHuman(zombie)) {
                    continue;
                }
                float dx = zombie.getX() - shell.getX();
                float dy = zombie.getY() - shell.getY();
                float d2 = dx * dx + dy * dy;
                if (d2 < best) {
                    best = d2;
                    nearest = zombie;
                }
            }
            if (nearest == null) {
                return "COMBAT_FAILED NO_ZOMBIE_IN_CELL";
            }
            var combat = combats.computeIfAbsent(shell, ignored -> new com.sao.engine.SAOCombat());
            return combat.begin(shell, nearest, live);
        } catch (Throwable throwable) {
            SAOAgent.log("beginCombatNearest threw: " + throwable);
            return "COMBAT_FAILED " + throwable;
        }
    }

    /**
     * Doctrine entry: open the combat loop on a named PERSON (shell or real
     * player) within reach of this shell. Standing permission is checked by
     * the caller; this only resolves and begins. Returns the combat verdict
     * string or a NOT_FOUND failure.
     */
    public String beginCombatWithName(Object object, String name, double radius) {
        try {
            if (!(object instanceof SAOIsoPlayerShell shell) || name == null) {
                return "COMBAT_FAILED INVALID_TARGET";
            }
            zombie.iso.IsoCell cell = shell.getCell();
            if (cell == null) {
                return "COMBAT_FAILED NO_CELL";
            }
            zombie.characters.IsoGameCharacter found = null;
            float bestDistance = (float) (radius * radius);
            for (zombie.iso.IsoMovingObject moving : cell.getObjectList()) {
                if (!(moving instanceof zombie.characters.IsoPlayer person)
                    || person == shell || person.isDead()) {
                    continue;
                }
                String username = person.getUsername();
                if (username == null || !username.equals(name)) {
                    continue;
                }
                float dx = person.getX() - shell.getX();
                float dy = person.getY() - shell.getY();
                float distance = dx * dx + dy * dy;
                if (distance <= bestDistance) {
                    bestDistance = distance;
                    found = person;
                }
            }
            if (found == null) {
                return "COMBAT_FAILED PERSON_NOT_FOUND name=" + name;
            }
            var combat = combats.computeIfAbsent(shell,
                ignored -> new com.sao.engine.SAOCombat());
            return combat.begin(shell, found, true);
        } catch (Throwable throwable) {
            SAOAgent.log("beginCombatWithName threw: " + throwable);
            return "COMBAT_FAILED EXCEPTION " + throwable;
        }
    }

    /**
     * [C20] The unstick verb's hand (DR-024 parity with the absorbed
     * framework's own "unstick"): clear BOTH movement-intent surfaces
     * - the body-level intent and the animation control vars - which
     * is the stop contract Lua cannot reach (F-004's two-surface law;
     * the private helper below this class has always owned it).
     */
    public String unstick(Object object) {
        try {
            if (!(object instanceof SAOIsoPlayerShell shell)) {
                return "NOT_A_SHELL";
            }
            clearMovementIntent(shell);
            return "CLEARED";
        } catch (Throwable throwable) {
            SAOAgent.log("unstick threw: " + throwable);
            return "UNSTICK_FAILED " + throwable;
        }
    }

    /**
     * [C16] The dead census - DR-021's instrument. Reads and derives
     * nothing itself: the fungible crowd and the identity-bearing
     * bodies in the loaded area (the [C9] predicate splits them), the
     * loaded area's tile extent (IsoChunkMap's public tile bounds,
     * javap-verified), and the installed map's extent (IsoMetaGrid
     * cells times IsoCell.getCellSizeInSquares()). One string of raw
     * numbers; every derived figure is the reader's arithmetic with
     * its assumptions stated beside it. Changes nothing, teaches
     * nothing - the [C6] instrument discipline.
     */
    public String deadCensus(Object playerObject) {
        try {
            if (!(playerObject instanceof zombie.characters.IsoPlayer player)) {
                return "";
            }
            zombie.iso.IsoCell cell = player.getCell();
            if (cell == null) {
                return "";
            }
            int crowd = 0;
            int marked = 0;
            var zombies = cell.getZombieList();
            for (int i = 0; i < zombies.size(); i++) {
                var zed = zombies.get(i);
                if (zed == null || zed.isDead()) {
                    continue;
                }
                if (com.sao.engine.SAOKnox.identityBearing(zed)) {
                    marked++;
                } else {
                    crowd++;
                }
            }
            long loadedTiles = 0;
            try {
                zombie.iso.IsoChunkMap chunks = cell.getChunkMap(0);
                if (chunks != null) {
                    long w = chunks.getWorldXMaxTiles()
                        - chunks.getWorldXMinTiles();
                    long h = chunks.getWorldYMaxTiles()
                        - chunks.getWorldYMinTiles();
                    if (w > 0 && h > 0) {
                        loadedTiles = w * h;
                    }
                }
            } catch (Throwable ignored) {
            }
            long mapTiles = 0;
            try {
                zombie.iso.IsoMetaGrid grid =
                    zombie.iso.IsoWorld.instance.getMetaGrid();
                long cellSquares = zombie.iso.IsoCell.getCellSizeInSquares();
                mapTiles = (long) grid.getWidth() * grid.getHeight()
                    * cellSquares * cellSquares;
            } catch (Throwable ignored) {
            }
            return "crowd=" + crowd + "|marked=" + marked
                + "|loadedTiles=" + loadedTiles + "|mapTiles=" + mapTiles;
        } catch (Throwable throwable) {
            SAOAgent.log("deadCensus threw: " + throwable);
            return "";
        }
    }

    /**
     * [C11] The engine's own bite clock, read rather than mirrored
     * (F-047). On this build a bite infects with CERTAINTY under any
     * transmission that includes saliva ({@code BodyPart.SetBitten},
     * offsets 102-127 - no roll exists), and the infected die exactly at
     * {@code infectionTime + infectionMortalityDuration} on the
     * character's own hours-survived clock ({@code BodyDamage.Update},
     * offsets 1976-2034: progress 1.0 is {@code ReduceGeneralHealth(110)}).
     * Returns the hours left until that death: "" when the body carries
     * no Knox infection (unbitten, Transmission None, or Mortality
     * Never's fake infection), "unpicked" when infected but the course
     * has not stamped its clock yet - the caller then mirrors the
     * sandbox window, citing {@code pickMortalityDuration}.
     */
    public String biteHoursLeft(Object object) {
        try {
            if (!(object instanceof zombie.characters.IsoPlayer person)) {
                return "";
            }
            zombie.characters.BodyDamage.BodyDamage damage =
                person.getBodyDamage();
            if (damage == null || !damage.isInfected()) {
                return "";
            }
            float began = damage.getInfectionTime();
            float duration = damage.getInfectionMortalityDuration();
            if (began < 0.0f || duration < 0.0f) {
                return "unpicked";
            }
            double left = (began + duration) - person.getHoursSurvived();
            return String.valueOf(left < 0.0 ? 0.0 : left);
        } catch (Throwable throwable) {
            SAOAgent.log("biteHoursLeft threw: " + throwable);
            return "";
        }
    }

    /**
     * [C10] The promise swings at the BODY. Open the combat loop on the
     * ONE risen body carrying this person id ([C8]'s modData mark, the
     * only identity that survives the turn - F-045). This is the argued
     * exception to [C9]'s identity skip: mercy FIGHTS the risen known
     * face - the keeper's own promise, kill not puppetry, and never a
     * stranger's body standing closer.
     */
    public String beginCombatWithPersonId(Object object, String personId,
        double radius) {
        try {
            if (!(object instanceof SAOIsoPlayerShell shell)
                || personId == null || personId.isEmpty()) {
                return "COMBAT_FAILED INVALID_TARGET";
            }
            zombie.iso.IsoCell cell = shell.getCell();
            if (cell == null) {
                return "COMBAT_FAILED NO_CELL";
            }
            zombie.characters.IsoZombie found = null;
            float bestDistance = (float) (radius * radius);
            var zombies = cell.getZombieList();
            for (int index = 0; index < zombies.size(); index++) {
                var zed = zombies.get(index);
                if (zed == null || zed.isDead()) {
                    continue;
                }
                Object mark;
                try {
                    mark = zed.getModData().rawget("SAOPersonId");
                } catch (Throwable ignored) {
                    continue;
                }
                if (!personId.equals(mark)) {
                    continue;
                }
                float dx = zed.getX() - shell.getX();
                float dy = zed.getY() - shell.getY();
                float distance = dx * dx + dy * dy;
                if (distance <= bestDistance) {
                    bestDistance = distance;
                    found = zed;
                }
            }
            if (found == null) {
                return "COMBAT_FAILED BODY_NOT_FOUND id=" + personId;
            }
            var combat = combats.computeIfAbsent(shell,
                ignored -> new com.sao.engine.SAOCombat());
            return combat.begin(shell, found, true);
        } catch (Throwable throwable) {
            SAOAgent.log("beginCombatWithPersonId threw: " + throwable);
            return "COMBAT_FAILED EXCEPTION " + throwable;
        }
    }

    /**
     * [C8] The turn is real - the lawful corpse net (F-044).
     *
     * The engine's whole death law hangs off {@code die()}: it builds the
     * corpse ({@code becomeCorpse} -> {@code new IsoDeadBody(chr)}, whose
     * constructor copies the character's modData AND descriptor onto the
     * corpse), and firing the died-listeners is what arms reanimation -
     * {@code IsoPlayer}'s own constructor registers a listener that calls
     * {@code body.reanimateLater()} under {@code shouldBecomeZombieAfterDeath()},
     * the sandbox Transmission switch over real infection. All of that is
     * the engine's code; none of it is ours.
     *
     * But {@code die()} itself is only invoked from
     * {@code PlayerOnGroundState.execute} and two server-only sites, so a
     * shell that dies without its state machine reaching the on-ground
     * state is a dead character standing in the world: no corpse, no
     * timer, no turn. This verb closes that gap with the engine's own
     * method - {@code die()} is public, final, and idempotent (guarded by
     * {@code onDeathDone} and {@code diedBody}), so calling it here either
     * does exactly what the state machine would have done or does nothing.
     *
     * Never for the risen or the neighbour framework's people: an
     * {@code IsoZombie} body is not ours to fold into a corpse.
     */
    public String ensureCorpse(Object object) {
        try {
            if (object instanceof zombie.characters.IsoZombie) {
                return "NOT_OURS";
            }
            if (!(object instanceof zombie.characters.IsoGameCharacter chr)) {
                return "NOT_A_CHARACTER";
            }
            if (!chr.isDead()) {
                return "ALIVE";
            }
            if (chr.getCurrentSquare() == null) {
                // The corpse constructor removes the character from the
                // world (ctor offsets 1159-1163), so a dead character with
                // no square already went through it.
                return "ALREADY_CORPSE";
            }
            chr.die();
            return chr.getCurrentSquare() == null ? "DIED" : "DIE_PENDING";
        } catch (Throwable throwable) {
            SAOAgent.log("ensureCorpse threw: " + throwable);
            return "DIE_FAILED " + throwable;
        }
    }

    /** "ranged:<ammo>" when the primary is a firearm, "melee" when a hand
     * weapon, "" when unarmed - one string, no object crossing. */
    public String describeWeapon(Object object) {
        try {
            if (!(object instanceof SAOIsoPlayerShell shell)) {
                return "";
            }
            if (!(shell.getPrimaryHandItem()
                instanceof zombie.inventory.types.HandWeapon weapon)) {
                return "";
            }
            if (weapon.isRanged()) {
                return "ranged:" + com.sao.engine.SAOCombat.ammoCount(weapon);
            }
            return "melee";
        } catch (Throwable throwable) {
            return "";
        }
    }

    /** Equip the best loaded firearm from the pack; verdict string. */
    public String equipBestRanged(Object object) {
        try {
            if (object instanceof SAOIsoPlayerShell shell) {
                return com.sao.engine.SAOEquipment.equipBestRanged(shell);
            }
            return "NOT_A_SHELL";
        } catch (Throwable throwable) {
            return "EXCEPTION " + throwable;
        }
    }

    /** Line of sight between two bodies (the scanner's own occlusion
     * primitive, exposed for speech gating). */
    public boolean hasLineTo(Object fromObject, Object toObject) {
        try {
            if (!(fromObject instanceof zombie.characters.IsoPlayer from)
                || !(toObject instanceof zombie.characters.IsoPlayer to)) {
                return false;
            }
            zombie.iso.IsoGridSquare eye = from.getCurrentSquare();
            zombie.iso.IsoGridSquare target = to.getCurrentSquare();
            if (eye == null || target == null) {
                return false;
            }
            return !eye.isSomethingTo(target);
        } catch (Throwable throwable) {
            return false;
        }
    }

    public String tickCombat(Object object) {
        try {
            if (!(object instanceof SAOIsoPlayerShell shell)) {
                return "NOT_A_SHELL";
            }
            var combat = combats.get(shell);
            return combat == null ? "COMBAT_IDLE" : combat.tick();
        } catch (Throwable throwable) {
            SAOAgent.log("tickCombat threw: " + throwable);
            return "COMBAT_TICK_FAILED " + throwable;
        }
    }

    public String resetCombat(Object object) {
        try {
            if (object instanceof SAOIsoPlayerShell shell) {
                var combat = combats.remove(shell);
                if (combat != null) {
                    combat.reset();
                }
            }
            return "COMBAT_RESET";
        } catch (Throwable throwable) {
            return "COMBAT_RESET_FAILED " + throwable;
        }
    }

    /** Direct the nearest zombie at the shell (incoming-combat bridge). */
    public String directNearestZombieAt(Object object) {
        try {
            if (!(object instanceof SAOIsoPlayerShell shell)) {
                return "NOT_A_SHELL";
            }
            zombie.iso.IsoCell cell = shell.getCell();
            if (cell == null) {
                return "NO_CELL";
            }
            zombie.characters.IsoZombie nearest = null;
            float best = Float.MAX_VALUE;
            var zombies = cell.getZombieList();
            for (int index = 0; index < zombies.size(); index++) {
                var zed = zombies.get(index);
                if (zed == null || zed.isDead()
                    // [C9] Choreograph only the fungible crowd: a living
                    // neighbour is a person (DR-009), and a risen known
                    // body's brain is vanilla's, not ours to point
                    // (DR-016 - one brain per body).
                    || com.sao.engine.SAOKnox.identityBearing(zed)) {
                    continue;
                }
                float dx = zed.getX() - shell.getX();
                float dy = zed.getY() - shell.getY();
                float d2 = dx * dx + dy * dy;
                if (d2 < best) {
                    best = d2;
                    nearest = zed;
                }
            }
            if (nearest == null) {
                return "NO_ZOMBIE_IN_CELL";
            }
            return com.sao.engine.SAOZombieDirector.direct(nearest, shell);
        } catch (Throwable throwable) {
            SAOAgent.log("directNearestZombieAt threw: " + throwable);
            return "DIRECT_FAILED " + throwable;
        }
    }

    /** The engine-generated name of a shell's descriptor, for record backfill. */
    public String getShellName(Object object) {
        try {
            if (!(object instanceof SAOIsoPlayerShell shell)) {
                return "";
            }
            var descriptor = shell.getDescriptor();
            if (descriptor == null) {
                return "";
            }
            return descriptor.getForename() + "|" + descriptor.getSurname();
        } catch (Throwable throwable) {
            return "";
        }
    }

    /** Who last hurt this body: "player:<name>" | "shell:<name>" | "zombie" | "". */
    public String getLastAttackerTag(Object object) {
        try {
            if (!(object instanceof SAOIsoPlayerShell shell)) {
                return "";
            }
            IsoGameCharacter attacker = shell.getAttackedBy();
            if (attacker == null) {
                return "";
            }
            if (attacker instanceof SAOIsoPlayerShell other) {
                return "shell:" + other.getUsername();
            }
            if (attacker instanceof IsoPlayer player) {
                return "player:" + player.getUsername();
            }
            if (attacker instanceof zombie.characters.IsoZombie zombieAttacker) {
                if (com.sao.engine.SAOKnox.isKnoxHuman(zombieAttacker)) {
                    // DR-009: a legacy Knox human's blow is a PERSON's
                    // blow - hostility and testimony carry their name,
                    // not a bite mark.
                    return "player:" + com.sao.engine.SAOKnox.knoxName(zombieAttacker);
                }
                return "zombie";
            }
            return "other";
        } catch (Throwable throwable) {
            return "";
        }
    }

    /** Health read for Lua's hurt tracking (engine object stays here). */
    public double getShellHealth(Object object) {
        try {
            if (!(object instanceof SAOIsoPlayerShell shell)) {
                return -1.0;
            }
            return shell.getBodyDamage().getHealth();
        } catch (Throwable throwable) {
            return -1.0;
        }
    }

    /** Needs read: "h=..|t=..|f=..|e=.." or "" (SAONeeds). */
    public String getNeeds(Object object) {
        if (object instanceof SAOIsoPlayerShell shell) {
            return com.sao.engine.SAONeeds.read(shell);
        }
        return "";
    }

    /** [C33] The fullest alcoholic drink carried, for the vanilla fluid
     *  action; null when there is none or the body is not ours. */
    public Object findCarriedAlcohol(Object object) {
        if (object instanceof SAOIsoPlayerShell shell) {
            return com.sao.engine.SAONeeds.bestCarriedDrinkAlcohol(shell);
        }
        return null;
    }

    /** [C33] Scan for a container holding a drink; "x:y:z:name" or "". */
    public String findAlcoholSource(Object object, double radius) {
        if (object instanceof SAOIsoPlayerShell shell) {
            return com.sao.engine.SAONeeds.findDrinkSourceNear(shell, (int) radius);
        }
        return "";
    }

    /** [C33] Whether an item is an alcoholic drink (a fluid container in
     *  the Alcoholic category with something in it). */
    public boolean isAlcoholicDrink(Object item) {
        return com.sao.engine.SAONeeds.isDrinkAlcoholic(item);
    }

    /** Best carried food as an opaque object for vanilla action constructors. */
    public Object findCarriedFood(Object object) {
        if (object instanceof SAOIsoPlayerShell shell) {
            return com.sao.engine.SAONeeds.bestCarriedFood(shell);
        }
        return null;
    }

    /** Scan for a world food source; "x:y:z:name" or "". */
    public String findFoodSource(Object object, double radius) {
        if (object instanceof SAOIsoPlayerShell shell) {
            return com.sao.engine.SAONeeds.findFoodSourceNear(shell, (int) radius);
        }
        return "";
    }

    public Object foodSourceItem(Object object) {
        if (object instanceof SAOIsoPlayerShell shell) {
            return com.sao.engine.SAONeeds.sourceItem(shell);
        }
        return null;
    }

    public Object foodSourceContainer(Object object) {
        if (object instanceof SAOIsoPlayerShell shell) {
            return com.sao.engine.SAONeeds.sourceContainer(shell);
        }
        return null;
    }

    public boolean foodSourceWithinReach(Object object) {
        return object instanceof SAOIsoPlayerShell shell
            && com.sao.engine.SAONeeds.sourceWithinReach(shell);
    }

    public void clearFoodSource(Object object) {
        if (object instanceof SAOIsoPlayerShell shell) {
            com.sao.engine.SAONeeds.clearSource(shell);
        }
    }

    /** Best carried drinkable as an opaque object, or null. */
    public Object findCarriedDrink(Object object) {
        if (object instanceof SAOIsoPlayerShell shell) {
            return com.sao.engine.SAONeeds.bestCarriedDrink(shell);
        }
        return null;
    }

    /** Scan for a clean world water source; "x:y:z" or "". */
    public String findWaterSource(Object object, double radius) {
        if (object instanceof SAOIsoPlayerShell shell) {
            return com.sao.engine.SAONeeds.findWaterSourceNear(shell, (int) radius);
        }
        return "";
    }

    public Object waterSourceObject(Object object) {
        if (object instanceof SAOIsoPlayerShell shell) {
            return com.sao.engine.SAONeeds.waterSource(shell);
        }
        return null;
    }

    public boolean waterSourceWithinReach(Object object) {
        return object instanceof SAOIsoPlayerShell shell
            && com.sao.engine.SAONeeds.waterSourceWithinReach(shell);
    }

    public void clearWaterSource(Object object) {
        if (object instanceof SAOIsoPlayerShell shell) {
            com.sao.engine.SAONeeds.clearWaterSource(shell);
        }
    }

    /** Scan for a container weapon clearly better than carried; "x:y:z:name" or "". */
    public String findWeaponUpgrade(Object object, double radius) {
        if (object instanceof SAOIsoPlayerShell shell) {
            return com.sao.engine.SAONeeds.findWeaponUpgradeNear(shell, (int) radius);
        }
        return "";
    }

    public Object weaponSourceItem(Object object) {
        if (object instanceof SAOIsoPlayerShell shell) {
            return com.sao.engine.SAONeeds.weaponSourceItem(shell);
        }
        return null;
    }

    public Object weaponSourceContainer(Object object) {
        if (object instanceof SAOIsoPlayerShell shell) {
            return com.sao.engine.SAONeeds.weaponSourceContainer(shell);
        }
        return null;
    }

    public boolean weaponSourceWithinReach(Object object) {
        return object instanceof SAOIsoPlayerShell shell
            && com.sao.engine.SAONeeds.weaponSourceWithinReach(shell);
    }

    public void clearWeaponSource(Object object) {
        if (object instanceof SAOIsoPlayerShell shell) {
            com.sao.engine.SAONeeds.clearWeaponSource(shell);
        }
    }

    /** Actively bleeding body-part count. */
    /** Dress a SHELL in a named vanilla outfit ([A20]) - only our own
     * bodies; another mod's dress is their business. */
    public boolean dressInOutfit(Object object, String outfitName) {
        try {
            if (!(object instanceof com.sao.engine.SAOIsoPlayerShell shell)
                || outfitName == null || outfitName.isEmpty()) {
                return false;
            }
            shell.dressInNamedOutfit(outfitName);
            shell.resetModelNextFrame();
            return true;
        } catch (Throwable throwable) {
            return false;
        }
    }

    /** A dress call that returns is not a dressed body ([C26], R-006).
     * The operator watched two of the county's people stand naked in a
     * kitchen while the log said dressed=true - dressInRandomOutfit
     * returned without throwing and the body wore nothing. So the
     * county verifies OUTCOMES now: count what is actually worn
     * (getWornItems().size(), javap-verified on
     * zombie.characters.WornItems.WornItems); if zero, try the random
     * wardrobe once more, then fall back to the named outfit the
     * caller offers, and say plainly which happened. Returns
     * "worn=<n>" when already dressed, "redressed=<n>" when a retry or
     * fallback clothed them, "NAKED" when nothing did. */
    public String ensureDressed(Object object, String fallbackOutfit) {
        try {
            if (!(object instanceof com.sao.engine.SAOIsoPlayerShell shell)) {
                return "NOT_OURS";
            }
            int worn = shell.getWornItems() == null
                ? 0 : shell.getWornItems().size();
            if (worn > 0) {
                return "worn=" + worn;
            }
            shell.dressInRandomOutfit();
            worn = shell.getWornItems() == null
                ? 0 : shell.getWornItems().size();
            if (worn == 0 && fallbackOutfit != null && !fallbackOutfit.isEmpty()) {
                shell.dressInNamedOutfit(fallbackOutfit);
                worn = shell.getWornItems() == null
                    ? 0 : shell.getWornItems().size();
            }
            shell.resetModelNextFrame();
            return worn > 0 ? "redressed=" + worn : "NAKED";
        } catch (Throwable throwable) {
            return "NAKED_THREW:" + throwable;
        }
    }

    /** Measure what in-process inference costs on this machine
     * ([C28], SPEECH_ML_DESIGN.md: the frame budget is measured
     * before any training run fixes a model size). Runs a
     * model-shaped workload - `layers` chained dim-by-dim
     * matrix-times-vector passes in float32 with a tanh between,
     * the dominant cost of a small network's forward pass - on the
     * CALLING thread, which is the honest worst case (a worker
     * thread would lift the per-frame ceiling; that choice comes
     * later, with this number in hand). Deterministic fill, one
     * warm pass for the JIT, and the checksum rides the report so
     * nothing is optimized away.
     * Returns "dim=..|layers=..|runs=..|avgUs=..|minUs=..|maxUs=..|sum=..". */
    public String inferenceBudgetProbe(double dimD, double layersD, double runsD) {
        try {
            int dim = Math.max(8, Math.min(2048, (int) dimD));
            int layers = Math.max(1, Math.min(64, (int) layersD));
            int runs = Math.max(1, Math.min(200, (int) runsD));
            float[][] weights = new float[layers][];
            for (int l = 0; l < layers; l++) {
                float[] w = new float[dim * dim];
                for (int i = 0; i < w.length; i++) {
                    w[i] = ((i % 97) - 48) / 97.0f;
                }
                weights[l] = w;
            }
            float[] vec = new float[dim];
            for (int i = 0; i < dim; i++) {
                vec[i] = ((i % 13) - 6) / 13.0f;
            }
            budgetForward(weights, vec, dim, layers);
            long min = Long.MAX_VALUE, max = 0, total = 0;
            float sum = 0;
            for (int r = 0; r < runs; r++) {
                long t0 = System.nanoTime();
                sum += budgetForward(weights, vec, dim, layers);
                long dt = System.nanoTime() - t0;
                total += dt;
                if (dt < min) { min = dt; }
                if (dt > max) { max = dt; }
            }
            return "dim=" + dim + "|layers=" + layers + "|runs=" + runs
                + "|avgUs=" + (total / runs / 1000L)
                + "|minUs=" + (min / 1000L)
                + "|maxUs=" + (max / 1000L)
                + "|sum=" + (long) sum;
        } catch (Throwable throwable) {
            return "PROBE_THREW:" + throwable;
        }
    }

    private static float budgetForward(float[][] weights, float[] vec,
                                       int dim, int layers) {
        float[] x = vec.clone();
        float[] y = new float[dim];
        for (int l = 0; l < layers; l++) {
            float[] w = weights[l];
            for (int i = 0; i < dim; i++) {
                float acc = 0;
                int row = i * dim;
                for (int j = 0; j < dim; j++) {
                    acc += w[row + j] * x[j];
                }
                y[i] = (float) Math.tanh(acc);
            }
            float[] t = x;
            x = y;
            y = t;
        }
        float out = 0;
        for (int i = 0; i < dim; i++) {
            out += x[i];
        }
        return out;
    }

    /** Nearest container object near a shell (deposit target), or null. */
    public Object findNearbyContainer(Object object, double radius) {
        if (object instanceof com.sao.engine.SAOIsoPlayerShell shell) {
            return com.sao.engine.SAONeeds.nearestContainer(shell, (int) radius);
        }
        return null;
    }

    /** Drop a READABLE note into the world ([A24]) - a titled
     * notebook on a loaded square; the county writes itself where the
     * player can find it. Verified: AddWorldInventoryItem(String,...)
     * returns the created item. */
    public boolean dropNoteAt(Object playerObject, int x, int y, int z,
                              String title, String page) {
        try {
            if (!(playerObject instanceof zombie.characters.IsoPlayer player)
                || title == null) {
                return false;
            }
            zombie.iso.IsoCell cell = player.getCell();
            zombie.iso.IsoGridSquare square =
                cell == null ? null : cell.getGridSquare(x, y, z);
            if (square == null) {
                return false;
            }
            zombie.inventory.InventoryItem item =
                square.AddWorldInventoryItem("Base.Notebook", 0.3f, 0.3f, 0.0f);
            if (item instanceof zombie.inventory.types.Literature note) {
                note.setName(title);
                note.setCustomName(true);
                if (page != null && !page.isEmpty()) {
                    note.addPage(1, page);
                    note.setNumberOfPages(Math.max(1, note.getNumberOfPages()));
                }
            }
            return item != null;
        } catch (Throwable throwable) {
            return false;
        }
    }

    /** Small honest XP for doing ([A24]): the verified engine grant
     * (getXp().AddXP(Perk, float)) - work teaches. Perk resolved by
     * name from the engine's own enum; unknown names no-op. Shells
     * only. */
    /** [B2] Live perk level on a shell, or -1. Same resolve idiom as
     *  grantXP - the perk registry's own ids. */
    public int getPerkLevel(Object object, String perkName) {
        try {
            if (!(object instanceof com.sao.engine.SAOIsoPlayerShell shell)
                || perkName == null) {
                return -1;
            }
            for (zombie.characters.skills.PerkFactory.Perk candidate
                    : zombie.characters.skills.PerkFactory.PerkList) {
                if (candidate != null
                    && perkName.equalsIgnoreCase(
                        String.valueOf(candidate.getId()))) {
                    return shell.getPerkLevel(candidate);
                }
            }
        } catch (Throwable throwable) {
            SAOAgent.log("getPerkLevel threw: " + throwable);
        }
        return -1;
    }

    /** [B2] The engine profession definition's own xp boost for a
     *  perk - the dormant baseline, same truth materialization
     *  applies to live shells. Returns 0 when the trade carries no
     *  boost, -1 on unknown profession/perk. */
    public int professionBoost(String professionPath, String perkName) {
        try {
            if (professionPath == null || perkName == null) return -1;
            zombie.scripting.objects.ResourceLocation location =
                zombie.scripting.objects.ResourceLocation.of(professionPath);
            zombie.scripting.objects.CharacterProfession profession =
                zombie.scripting.objects.CharacterProfession.get(location);
            if (profession == null) return -1;
            zombie.characters.professions.CharacterProfessionDefinition def =
                zombie.characters.professions.CharacterProfessionDefinition
                    .getCharacterProfessionDefinition(profession);
            if (def == null) return -1;
            java.util.HashMap<zombie.characters.skills.PerkFactory.Perk,
                Integer> boosts = def.getXpBoosts();
            if (boosts == null) return 0;
            for (java.util.Map.Entry<zombie.characters.skills.PerkFactory
                    .Perk, Integer> entry : boosts.entrySet()) {
                if (entry.getKey() != null && perkName.equalsIgnoreCase(
                        String.valueOf(entry.getKey().getId()))) {
                    Integer level = entry.getValue();
                    return level == null ? 0 : level.intValue();
                }
            }
            return 0;
        } catch (Throwable throwable) {
            SAOAgent.log("professionBoost threw: " + throwable);
        }
        return -1;
    }

    public boolean grantXP(Object object, String perkName, double amount) {
        try {
            if (!(object instanceof com.sao.engine.SAOIsoPlayerShell shell)
                || perkName == null || amount <= 0) {
                return false;
            }
            zombie.characters.skills.PerkFactory.Perk perk = null;
            for (zombie.characters.skills.PerkFactory.Perk candidate
                    : zombie.characters.skills.PerkFactory.PerkList) {
                if (candidate != null
                    && perkName.equalsIgnoreCase(String.valueOf(candidate.getId()))) {
                    perk = candidate;
                    break;
                }
            }
            if (perk == null) {
                return false;
            }
            // [C31] A child learns at the age's pace (the shell's xpScale);
            // strength, fitness and sprinting are exempt - the birthday
            // floors pace those, and a quarter of a small packet rounds
            // to nothing (Growing Up's own finding, CREDITS.md).
            String id = String.valueOf(perk.getId());
            float scaled = (float) amount;
            if (!("Strength".equalsIgnoreCase(id)
                  || "Fitness".equalsIgnoreCase(id)
                  || "Sprinting".equalsIgnoreCase(id))) {
                scaled = scaled * shell.xpScale;
            }
            shell.getXp().AddXP(perk, scaled);
            return true;
        } catch (Throwable throwable) {
            return false;
        }
    }

    /** Give a written journal ([A24]): a notebook titled with the
     * owner's name, pages supplied by Lua (already-rendered claim
     * text). Literature surface verified: addPage/setName/
     * setCustomName. Shell-only. */
    public boolean giveJournal(Object object, String title, String page1,
                               String page2) {
        try {
            if (!(object instanceof com.sao.engine.SAOIsoPlayerShell shell)
                || title == null) {
                return false;
            }
            zombie.inventory.InventoryItem item =
                shell.getInventory().AddItem("Base.Notebook");
            if (!(item instanceof zombie.inventory.types.Literature journal)) {
                return item != null;
            }
            journal.setName(title);
            journal.setCustomName(true);
            int pages = 0;
            if (page1 != null && !page1.isEmpty()) {
                pages++;
                journal.addPage(pages, page1);
            }
            if (page2 != null && !page2.isEmpty()) {
                pages++;
                journal.addPage(pages, page2);
            }
            if (pages > 0) {
                journal.setNumberOfPages(Math.max(pages,
                    journal.getNumberOfPages()));
            }
            return true;
        } catch (Throwable throwable) {
            return false;
        }
    }

    /** [C3] One person, one name - the papers say what the menu says.
     * Retitles the journal a record already carries and ensures an ID
     * card (the neighbour framework's own item types, proven on this
     * install by the card the operator looted) named with the LIVING
     * name, so the corpse identifies the person everyone knew.
     * Shell-only; the neighbour's own bodies carry the neighbour's
     * card. */
    public boolean refreshIdentityPapers(Object object, String name) {
        try {
            if (!(object instanceof com.sao.engine.SAOIsoPlayerShell shell)
                || name == null || name.isEmpty()) {
                return false;
            }
            boolean touched = false;
            String journalTitle = name + "'s journal";
            String cardTitle = name + " - ID";
            zombie.inventory.InventoryItem card = null;
            var items = shell.getInventory().getItems();
            for (int index = 0; index < items.size(); index++) {
                zombie.inventory.InventoryItem item = items.get(index);
                if (item == null) {
                    continue;
                }
                String type = String.valueOf(item.getFullType());
                String shown = String.valueOf(item.getName());
                if (type.contains("IDcard")) {
                    card = item;
                } else if (item instanceof zombie.inventory.types.Literature
                    && shown.endsWith("'s journal")
                    && !shown.equals(journalTitle)) {
                    item.setName(journalTitle);
                    item.setCustomName(true);
                    touched = true;
                }
            }
            if (card == null) {
                card = shell.getInventory().AddItem(
                    shell.isFemale() ? "Base.IDcard_Female"
                                     : "Base.IDcard_Male");
                touched = card != null;
            }
            if (card != null && !cardTitle.equals(card.getName())) {
                card.setName(cardTitle);
                card.setCustomName(true);
                touched = true;
            }
            return touched;
        } catch (Throwable throwable) {
            return false;
        }
    }

    /** [C3] The neighbour framework names its people from its own
     * profile table and never writes the descriptor, so the engine
     * descriptor carries a random name the neighbour never uses - and
     * this county was adopting THAT. Aligning the descriptor to the
     * profile name makes every reader (the scanner, knoxBodyByName,
     * this county's records) agree with the neighbour's menu and its
     * ID card: one person, one name. */
    public boolean alignKnoxName(Object object, String name) {
        try {
            if (!(object instanceof zombie.characters.IsoZombie zombie)
                || name == null || name.isEmpty()) {
                return false;
            }
            if (name.equals(com.sao.engine.SAOKnox.knoxName(zombie))) {
                return false;
            }
            SurvivorDesc desc = zombie.getDescriptor();
            if (desc == null) {
                return false;
            }
            desc.setForename(name);
            desc.setSurname("");
            return true;
        } catch (Throwable throwable) {
            return false;
        }
    }

    /** A giveable bandage from a shell's pack, or null ([A19]). */
    public Object findSpareBandage(Object object) {
        if (object instanceof com.sao.engine.SAOIsoPlayerShell shell) {
            return com.sao.engine.SAONeeds.spareBandage(shell);
        }
        return null;
    }

    public double getBleedingCount(Object object) {
        if (object instanceof zombie.characters.IsoGameCharacter character) {
            return com.sao.engine.SAONeeds.bleedingCount(character);
        }
        return 0;
    }

    /** Worst unbandaged bleeding part as an opaque object, or null. */
    public Object bleedingBodyPart(Object object) {
        if (object instanceof SAOIsoPlayerShell shell) {
            return com.sao.engine.SAONeeds.worstBleedingPart(shell);
        }
        return null;
    }

    /** Best carried bandage-capable item, or null. */
    public Object findBandage(Object object) {
        if (object instanceof SAOIsoPlayerShell shell) {
            return com.sao.engine.SAONeeds.bestBandage(shell);
        }
        return null;
    }

    /** The food a shell can spare (second-best carried), or null. */
    public Object findSpareFood(Object object) {
        if (object instanceof SAOIsoPlayerShell shell) {
            return com.sao.engine.SAONeeds.spareFood(shell);
        }
        return null;
    }

    /** Whether the shell carries rippable cloth (loose sheet or unworn clothing). */
    public boolean hasRippableCloth(Object object) {
        return object instanceof SAOIsoPlayerShell shell
            && com.sao.engine.SAONeeds.hasRippableCloth(shell);
    }

    /** Rip one carried cloth into rags; returns what was ripped or "". */
    public String ripClothForRags(Object object) {
        if (object instanceof SAOIsoPlayerShell shell) {
            return com.sao.engine.SAONeeds.ripClothForRags(shell);
        }
        return "";
    }

    /** Whether a carried firearm is dry with nothing loadable in the pack. */
    public boolean needsAmmo(Object object) {
        return object instanceof SAOIsoPlayerShell shell
            && com.sao.engine.SAONeeds.needsAmmo(shell);
    }

    /** Scan for compatible ammo in containers; "x:y:z:name" or "". */
    public String findAmmoSource(Object object, double radius) {
        if (object instanceof SAOIsoPlayerShell shell) {
            return com.sao.engine.SAONeeds.findAmmoSourceNear(shell, (int) radius);
        }
        return "";
    }

    public Object ammoSourceItem(Object object) {
        if (object instanceof SAOIsoPlayerShell shell) {
            return com.sao.engine.SAONeeds.ammoSourceItem(shell);
        }
        return null;
    }

    public Object ammoSourceContainer(Object object) {
        if (object instanceof SAOIsoPlayerShell shell) {
            return com.sao.engine.SAONeeds.ammoSourceContainer(shell);
        }
        return null;
    }

    public boolean ammoSourceWithinReach(Object object) {
        return object instanceof SAOIsoPlayerShell shell
            && com.sao.engine.SAONeeds.ammoSourceWithinReach(shell);
    }

    public void clearAmmoSource(Object object) {
        if (object instanceof SAOIsoPlayerShell shell) {
            com.sao.engine.SAONeeds.clearAmmoSource(shell);
        }
    }

    /** Pack what this body carries and is, for the record (F-013). */
    public String hibernate(Object object) {
        if (object instanceof SAOIsoPlayerShell shell) {
            return com.sao.engine.SAOHibernation.hibernate(shell);
        }
        return "";
    }

    /** Restore a snapshot onto a fresh body and run dormant metabolism. */
    public String awaken(Object object, String packed, double elapsedHours) {
        if (object instanceof SAOIsoPlayerShell shell) {
            return com.sao.engine.SAOHibernation.awaken(shell, packed, elapsedHours);
        }
        return "NOT_A_SHELL";
    }

    /** Fallback eat - the same engine call vanilla makes at action complete. */
    public boolean engineEat(Object object, Object itemObject) {
        if (object instanceof SAOIsoPlayerShell shell
            && itemObject instanceof zombie.inventory.InventoryItem item) {
            return com.sao.engine.SAONeeds.engineEat(shell, item);
        }
        return false;
    }

    /** A useful ground item within reach; display name or "". */
    public String findOfferedItem(Object object) {
        if (object instanceof SAOIsoPlayerShell shell) {
            return com.sao.engine.SAONeeds.findOfferedItemNear(shell);
        }
        return "";
    }

    /** The remembered ground item (opaque, for the vanilla grab), or null. */
    public Object offeredWorldItem(Object object) {
        if (object instanceof SAOIsoPlayerShell shell) {
            return com.sao.engine.SAONeeds.offeredWorldItem(shell);
        }
        return null;
    }

    public void clearOffered(Object object) {
        if (object instanceof SAOIsoPlayerShell shell) {
            com.sao.engine.SAONeeds.clearOffered(shell);
        }
    }

    /** Named corpses within radius: "name:x:y|..." or "". */
    public String findNamedCorpses(Object object, double radius) {
        if (object instanceof SAOIsoPlayerShell shell) {
            return com.sao.engine.SAONeeds.findNamedCorpsesNear(shell, (int) radius);
        }
        return "";
    }

    /** The drink a shell can spare (second-best carried), or null. */
    public Object findSpareDrink(Object object) {
        if (object instanceof SAOIsoPlayerShell shell) {
            return com.sao.engine.SAONeeds.spareDrink(shell);
        }
        return null;
    }

    /** Scout the best base candidate near this shell; compact string or "". */
    public String scoutBase(Object object, String rejectedCsv) {
        if (object instanceof SAOIsoPlayerShell shell) {
            return com.sao.engine.SAOSettlement.scout(shell, rejectedCsv);
        }
        return "";
    }

    /** Best carried smokable as an opaque object, or null. */
    public Object findCarriedSmokable(Object object) {
        if (object instanceof SAOIsoPlayerShell shell) {
            return com.sao.engine.SAONeeds.carriedSmokable(shell);
        }
        return null;
    }

    /** How many smokables the shell carries. */
    public double smokableCount(Object object) {
        if (object instanceof SAOIsoPlayerShell shell) {
            return com.sao.engine.SAONeeds.smokableCount(shell);
        }
        return 0;
    }

    /** Best carried food, spare rule waived (for the bonded). */
    public Object findFoodForBonded(Object object) {
        if (object instanceof SAOIsoPlayerShell shell) {
            return com.sao.engine.SAONeeds.bestFoodForBonded(shell);
        }
        return null;
    }

    /** Stamp an engine-registered profession onto a character's
     * descriptor by "namespace:path" key (census [A18]) - identity only;
     * skill grants are a future seam. */
    public boolean setProfession(Object object, String engineKey) {
        try {
            if (!(object instanceof zombie.characters.IsoGameCharacter character)
                || engineKey == null || engineKey.isEmpty()) {
                return false;
            }
            zombie.characters.SurvivorDesc desc = character.getDescriptor();
            if (desc == null) {
                return false;
            }
            zombie.scripting.objects.ResourceLocation location =
                zombie.scripting.objects.ResourceLocation.of(engineKey);
            zombie.scripting.objects.CharacterProfession profession =
                zombie.scripting.objects.CharacterProfession.get(location);
            if (profession == null) {
                return false;
            }
            desc.setCharacterProfession(profession);
            // The trade grants its skills ([A19]): the engine's own
            // definition carries the XP boosts; the descriptor gets the
            // profession skills, and OUR shell's live perk levels rise by
            // the boosts - initial-state construction, applied once at
            // materialization, never to another mod's body.
            try {
                zombie.characters.professions.CharacterProfessionDefinition def =
                    zombie.characters.professions.CharacterProfessionDefinition
                        .getCharacterProfessionDefinition(profession);
                if (def != null) {
                    try {
                        desc.setProfessionSkills(def);
                    } catch (Throwable ignored) {
                    }
                    if (character instanceof com.sao.engine.SAOIsoPlayerShell) {
                        java.util.HashMap<zombie.characters.skills.PerkFactory.Perk,
                            Integer> boosts = def.getXpBoosts();
                        if (boosts != null) {
                            for (java.util.Map.Entry<zombie.characters.skills
                                    .PerkFactory.Perk, Integer> entry
                                    : boosts.entrySet()) {
                                int current = character.getPerkLevel(entry.getKey());
                                int target = Math.min(10,
                                    current + Math.max(0, entry.getValue()));
                                if (target > current) {
                                    character.setPerkLevelDebug(entry.getKey(), target);
                                }
                            }
                        }
                    }
                }
            } catch (Throwable ignored) {
            }
            return true;
        } catch (Throwable throwable) {
            return false;
        }
    }

    /** Every profession registered with the engine - vanilla and any
     * mod's - as "namespace:path|..." (DR-010 census enumeration; the
     * namespace names the registering mod). */
    /** [B50] One field of a '|'-and-':' protocol, made safe to pack.
     *
     *  `dropColon` is for the field the Lua half reads as everything
     *  up to the FIRST colon - a colon inside it would truncate the
     *  value. The field after it keeps its colons, because the
     *  pattern's `(.+)$` takes the whole remainder.
     */
    private static String protocolField(String value, boolean dropColon) {
        if (value == null) {
            return "";
        }
        String out = value.replace('|', '_');
        return dropColon ? out.replace(':', '_') : out;
    }

    public String listProfessions() {
        try {
            StringBuilder out = new StringBuilder(256);
            for (zombie.scripting.objects.ResourceLocation key
                    : zombie.scripting.objects.Registries.CHARACTER_PROFESSION.keys()) {
                if (key == null) {
                    continue;
                }
                if (out.length() > 0) {
                    out.append('|');
                }
                // [B50] Somebody else's text in our protocol.
                //
                // Entries are joined by '|' and split by the first
                // ':'. Both of these strings come from whatever mod
                // registered the profession, so neither is ours to
                // trust: a '|' anywhere would split one profession
                // into two, and the Lua half
                // (`string.match(entry, "^([^:]+):(.+)$")`) would
                // return nil for the fragment without a colon and
                // silently skip it, leaving a phantom trade in the
                // census and a real one missing.
                //
                // The namespace loses ':' as well, because the match
                // above takes everything up to the FIRST colon as the
                // namespace - one inside it would truncate the mod's
                // own name. The path keeps its colons: the pattern's
                // `(.+)$` takes the whole remainder, so they survive
                // intact and the key still matches what the base
                // table stores.
                out.append(protocolField(key.getNamespace(), true))
                    .append(':')
                    .append(protocolField(key.getPath(), false));
            }
            return out.toString();
        } catch (Throwable throwable) {
            return "";
        }
    }

    /** Live Knox humans in the loaded world, from any player's cell:
     * "name:x:y:hoursSurvived|..." or "". DR-009 inhabitation edge. */
    public String listKnoxHumans(Object playerObject) {
        try {
            if (!(playerObject instanceof zombie.characters.IsoPlayer player)) {
                return "";
            }
            zombie.iso.IsoCell cell = player.getCell();
            if (cell == null) {
                return "";
            }
            StringBuilder out = new StringBuilder(64);
            var zombies = cell.getZombieList();
            for (int i = 0; i < zombies.size(); i++) {
                var zombie = zombies.get(i);
                if (zombie == null || zombie.isDead()
                    || !com.sao.engine.SAOKnox.isKnoxHuman(zombie)) {
                    continue;
                }
                if (out.length() > 0) {
                    out.append('|');
                }
                double hours = 0;
                try {
                    hours = zombie.getHoursSurvived();
                } catch (Throwable ignored) {
                }
                out.append(com.sao.engine.SAOKnox.knoxId(zombie))
                    .append(':')
                    .append(com.sao.engine.SAOKnox.knoxName(zombie)
                        .replace('|', '_').replace(':', '_'))
                    .append(':').append((int) zombie.getX())
                    .append(':').append((int) zombie.getY())
                    .append(':').append((int) hours);
            }
            return out.toString();
        } catch (Throwable throwable) {
            return "";
        }
    }

    /** The live body of a named Knox human, or null (opaque to Lua). */
    /** [B28] Another mod's IsoPlayer-based person, by the label the
     *  scanner gave them. The exact reverse of what the scanner
     *  computes, sharing its one classification, so a survivor who
     *  knows somebody by name can finally reach them - to bandage
     *  them, which is the only thing that ever needed a body. */
    public Object foreignBodyByName(Object playerObject, String name) {
        try {
            if (!(playerObject instanceof zombie.characters.IsoPlayer player)
                || name == null) {
                return null;
            }
            zombie.iso.IsoCell cell = player.getCell();
            if (cell == null) {
                return null;
            }
            for (zombie.iso.IsoMovingObject moving : cell.getObjectList()) {
                if (moving instanceof zombie.characters.IsoPlayer person
                    && !person.isDead()
                    && com.sao.engine.SAOPerceptionScanner
                        .isForeignPerson(person)
                    && name.equals(com.sao.engine.SAOPerceptionScanner
                        .foreignName(person))) {
                    return person;
                }
            }
        } catch (Throwable throwable) {
            SAOAgent.log("foreignBodyByName threw: " + throwable);
        }
        return null;
    }

    public Object knoxBodyByName(Object playerObject, String name) {
        try {
            if (!(playerObject instanceof zombie.characters.IsoPlayer player)
                || name == null) {
                return null;
            }
            zombie.iso.IsoCell cell = player.getCell();
            if (cell == null) {
                return null;
            }
            var zombies = cell.getZombieList();
            for (int i = 0; i < zombies.size(); i++) {
                var zombie = zombies.get(i);
                if (zombie != null
                    && com.sao.engine.SAOKnox.isKnoxHuman(zombie)
                    && name.equals(com.sao.engine.SAOKnox.knoxName(zombie))) {
                    return zombie;
                }
            }
            return null;
        } catch (Throwable throwable) {
            return null;
        }
    }

    /** Sleep flag on a shell (F-016: safe, inert, cosmetic + gating). */
    public void setShellAsleep(Object object, boolean asleep) {
        if (object instanceof SAOIsoPlayerShell shell) {
            com.sao.engine.SAONeeds.setShellAsleep(shell, asleep);
        }
    }

    /** Charge rest recovery for elapsed in-game hours; new fatigue or -1. */
    public double restRecoverTick(Object object, double hoursDelta) {
        if (object instanceof SAOIsoPlayerShell shell) {
            return com.sao.engine.SAONeeds.restRecoverTick(shell, hoursDelta);
        }
        return -1.0;
    }

    /** Whether the shell's own action stack still holds queued work. */
    public boolean hasPendingActions(Object object) {
        return object instanceof SAOIsoPlayerShell shell
            && com.sao.engine.SAONeeds.busy(shell);
    }

    public boolean isCombatPatchReady() {
        return com.sao.agent.SAOCombatGate.isPatchReady();
    }

    /** [B34] The footprint of the building this person stands in, as
     *  "minX:minY:maxX:maxY" inclusive, or "" when they stand in none.
     *
     *  A claim used to be a square of invented tiles centred on a pair
     *  of feet - and three different sites invented three different
     *  squares. The engine already keeps the real answer: a building
     *  knows its own bounds, and no two houses are the same size. This
     *  is the whole derivation; what to do when there is no building
     *  is a decision and belongs in Lua, not here.
     *
     *  IsoPlayer covers both the real player and our shells, because
     *  the shell extends it - the player claiming a house and a
     *  survivor settling one are then measured by the same ruler. */
    public String buildingBoundsAt(Object object) {
        try {
            if (!(object instanceof zombie.characters.IsoPlayer person)) {
                return "";
            }
            zombie.iso.IsoGridSquare square = person.getCurrentSquare();
            if (square == null) {
                return "";
            }
            zombie.iso.areas.IsoBuilding building = square.getBuilding();
            if (building == null || building.bounds == null) {
                return "";
            }
            java.awt.Rectangle bounds = building.bounds;
            if (bounds.width <= 0 || bounds.height <= 0) {
                return "";
            }
            return bounds.x + ":" + bounds.y + ":"
                + (bounds.x + bounds.width - 1) + ":"
                + (bounds.y + bounds.height - 1);
        } catch (Throwable throwable) {
            SAOAgent.log("buildingBoundsAt threw: " + throwable);
            return "";
        }
    }

    private SAORouteState routeState(SAOIsoPlayerShell shell) {
        return routes.computeIfAbsent(shell, ignored -> new SAORouteState());
    }

    /** Perception acquisition: one compact string, no engine objects to Lua. */
    public String perceive(Object object) {
        try {
            // [B41] Any character with a body. The real player
            // reached this and got "" back, which is why their
            // belief store only ever held what they were TOLD.
            if (!(object instanceof zombie.characters.IsoGameCharacter who)) {
                return "";
            }
            return com.sao.engine.SAOPerceptionScanner.scan(who);
        } catch (Throwable throwable) {
            SAOAgent.log("perceive threw: " + throwable);
            return "";
        }
    }

    /** Equipment verbs (typed ports). */
    public String equipBestMelee(Object object) {
        try {
            if (!(object instanceof SAOIsoPlayerShell shell)) {
                return "NOT_A_SHELL";
            }
            return com.sao.engine.SAOEquipment.equipBestMelee(shell);
        } catch (Throwable throwable) {
            SAOAgent.log("equipBestMelee threw: " + throwable);
            return "EQUIP_FAILED " + throwable;
        }
    }

    /** [A28] Scavenge the surroundings: place provides, person spots. */
    public int takeWantedFromNearby(Object object, int radius,
            String want, int max) {
        try {
            if (object instanceof IsoPlayer) {
                return com.sao.engine.SAONeeds.takeWantedFromNearby(
                    (IsoPlayer) object, radius, want, max);
            }
        } catch (Throwable throwable) {
            SAOAgent.log("takeWantedFromNearby threw: " + throwable);
        }
        return 0;
    }

    /** [B31] Burn fuel from the named vehicle near this shell, as a
     *  percentage of its tank. Returns what was actually burned. */
    public float spendVehicleFuel(Object object, int radius,
            String name, float percent) {
        try {
            if (object instanceof IsoPlayer) {
                return com.sao.engine.SAONeeds.spendVehicleFuel(
                    (IsoPlayer) object, radius, name, percent);
            }
        } catch (Throwable throwable) {
            SAOAgent.log("spendVehicleFuel threw: " + throwable);
        }
        return 0.0f;
    }

    /** [B26] What they kept, by both of the engine's words for a
     *  keepsake - the display category and the IS_MEMENTO tag. */
    public String carriedMemento(Object object) {
        try {
            if (object instanceof IsoPlayer) {
                return com.sao.engine.SAONeeds.carriedMemento(
                    (IsoPlayer) object);
            }
        } catch (Throwable throwable) {
            SAOAgent.log("carriedMemento threw: " + throwable);
        }
        return "";
    }

    /** [A28] Read what the place yielded, by display category. */
    public String carriedDisplayCategory(Object object, String cat) {
        try {
            if (object instanceof IsoPlayer) {
                return com.sao.engine.SAONeeds.carriedDisplayCategory(
                    (IsoPlayer) object, cat);
            }
        } catch (Throwable throwable) {
            SAOAgent.log("carriedDisplayCategory threw: " + throwable);
        }
        return "";
    }

    /** [B1] Seat a crew member near the player; engine contract. */
    public int seatInNearestVehicle(Object object, double px, double py) {
        try {
            if (object instanceof IsoPlayer) {
                return com.sao.engine.SAONeeds.seatInNearestVehicle(
                    (IsoPlayer) object, (float) px, (float) py);
            }
        } catch (Throwable throwable) {
            SAOAgent.log("seatInNearestVehicle threw: " + throwable);
        }
        return -1;
    }

    /** [B1] Release a seated crew member. */
    public boolean unseatFromVehicle(Object object) {
        try {
            if (object instanceof IsoPlayer) {
                return com.sao.engine.SAONeeds.unseatFromVehicle(
                    (IsoPlayer) object);
            }
        } catch (Throwable throwable) {
            SAOAgent.log("unseatFromVehicle threw: " + throwable);
        }
        return false;
    }

    /** [B9] The social state: "i=..|p=..|s=..|a=..|m=..". */
    public String socialState(Object object) {
        if (object instanceof IsoPlayer player) {
            return com.sao.engine.SAONeeds.socialState(player);
        }
        return "";
    }

    /** [B7] Wound-infection level (0 when clean). */
    public double woundInfection(Object object) {
        if (object instanceof IsoPlayer player) {
            return com.sao.engine.SAONeeds.woundInfection(player);
        }
        return 0.0;
    }

    /** [B7] Dirty dressings on this body. */
    public int dirtyBandages(Object object) {
        if (object instanceof IsoPlayer player) {
            return com.sao.engine.SAONeeds.dirtyBandages(player);
        }
        return 0;
    }

    /** [B7] Clean the worst wound with a carried alcohol item. */
    public String disinfectFromPack(Object object) {
        if (object instanceof IsoPlayer player) {
            return com.sao.engine.SAONeeds.disinfectFromPack(player);
        }
        return "";
    }

    /** [B7] How sick this shell is (a caught cold). */
    public double sickness(Object object) {
        if (object instanceof IsoPlayer player) {
            return com.sao.engine.SAONeeds.sickness(player);
        }
        return 0.0;
    }

    /** [B6] How cold this shell is (core-temperature deficit). */
    public double coldStrength(Object object) {
        if (object instanceof IsoPlayer player) {
            return com.sao.engine.SAONeeds.coldStrength(player);
        }
        return 0.0;
    }

    /** [B6] Nearest hearth with fuel: "x:y:z:fuel" or "". */
    public String hearthNear(Object object, int radius) {
        if (object instanceof IsoPlayer player) {
            return com.sao.engine.SAONeeds.hearthNear(player, radius);
        }
        return "";
    }

    /** [B6] Light a fuelled dead hearth if the means are carried. */
    public boolean lightNearbyHearth(Object object, int radius) {
        if (object instanceof IsoPlayer player) {
            return com.sao.engine.SAONeeds.lightNearbyHearth(player, radius);
        }
        return false;
    }

    /** [B6] Feed the nearest hearth; returns fuel units added. */
    public int feedNearbyHearth(Object object, int radius) {
        if (object instanceof IsoPlayer player) {
            return com.sao.engine.SAONeeds.feedNearbyHearth(player, radius);
        }
        return 0;
    }

    /** [B6] Fill carried vessels from a real source; units moved. */
    public double fillWaterFromNearby(Object object, int radius) {
        try {
            if (object instanceof IsoPlayer) {
                return com.sao.engine.SAONeeds.fillWaterFromNearby(
                    (IsoPlayer) object, radius);
            }
        } catch (Throwable throwable) {
            SAOAgent.log("fillWaterFromNearby threw: " + throwable);
        }
        return 0.0;
    }

    /** [B6] Read stored water in the surrounding containers. */
    public double countStoredWaterNearby(Object object, int radius) {
        try {
            if (object instanceof IsoPlayer) {
                return com.sao.engine.SAONeeds.countStoredWaterNearby(
                    (IsoPlayer) object, radius);
            }
        } catch (Throwable throwable) {
            SAOAgent.log("countStoredWaterNearby threw: " + throwable);
        }
        return 0.0;
    }

    /** [C60] Containers the engine says have been looted, "looted@total". */
    public String lootedNearby(Object object, int radius) {
        try {
            if (object instanceof IsoPlayer) {
                return com.sao.engine.SAONeeds.lootedNearby(
                    (IsoPlayer) object, radius);
            }
        } catch (Throwable throwable) {
            SAOAgent.log("lootedNearby threw: " + throwable);
        }
        return "0@0";
    }

    /** [B21] What THIS world contains - discovered from the live
     *  script registry, classified by how content describes itself.
     *  Never names a mod, so a changed load needs no code change. */
    public String surveyItems(int topCategories) {
        try {
            return com.sao.engine.SAOWorldCensus.surveyItems(topCategories);
        } catch (Throwable throwable) {
            SAOAgent.log("surveyItems threw: " + throwable);
        }
        return "";
    }

    /** [B21] What this world can DRIVE, by capability rather than by
     *  name - the county never needs to know a thing is called an RV,
     *  only that something here carries eight people and their gear. */
    public String surveyVehicles(int bigSeats) {
        try {
            return com.sao.engine.SAOWorldCensus.surveyVehicles(bigSeats);
        } catch (Throwable throwable) {
            SAOAgent.log("surveyVehicles threw: " + throwable);
        }
        return "";
    }

    /** [B21] What the music does to whoever can hear it. */
    public int easeListeners(Object object, int radius) {
        try {
            if (object instanceof IsoPlayer) {
                return com.sao.engine.SAONeeds.easeListeners(
                    (IsoPlayer) object, radius);
            }
        } catch (Throwable throwable) {
            SAOAgent.log("easeListeners threw: " + throwable);
        }
        return 0;
    }

    /** [B22] Take the book this survivor's trade rides on. */
    public boolean takeSkillBookFor(Object object, int radius, String perk) {
        try {
            if (object instanceof IsoPlayer) {
                return com.sao.engine.SAONeeds.takeSkillBookFor(
                    (IsoPlayer) object, radius, perk);
            }
        } catch (Throwable throwable) {
            SAOAgent.log("takeSkillBookFor threw: " + throwable);
        }
        return false;
    }

    /** [B22] Read it, through the engine's own ReadLiterature. */
    public String readSkillBook(Object object, String perk) {
        try {
            if (object instanceof IsoPlayer) {
                return com.sao.engine.SAONeeds.readSkillBook(
                    (IsoPlayer) object, perk);
            }
        } catch (Throwable throwable) {
            SAOAgent.log("readSkillBook threw: " + throwable);
        }
        return "";
    }

    /** [B22] How bored someone is, by the engine's own number. */
    public double boredom(Object object) {
        try {
            if (object instanceof IsoPlayer) {
                return com.sao.engine.SAONeeds.boredom((IsoPlayer) object);
            }
        } catch (Throwable throwable) {
            SAOAgent.log("boredom threw: " + throwable);
        }
        return 0.0;
    }

    /** [B22] What a keepsake is worth to the one carrying it. */
    public void steady(Object object, double morale) {
        try {
            if (object instanceof IsoPlayer) {
                com.sao.engine.SAONeeds.steady(
                    (IsoPlayer) object, (float) morale);
            }
        } catch (Throwable throwable) {
            SAOAgent.log("steady threw: " + throwable);
        }
    }

    /** [B21] Food still dangerous raw - the evidence against a
     *  cook, read with the same gate they cook against. */
    public int countRawDangerNearby(Object object, int radius) {
        try {
            if (object instanceof IsoPlayer) {
                return com.sao.engine.SAONeeds.countRawDangerNearby(
                    (IsoPlayer) object, radius);
            }
        } catch (Throwable throwable) {
            SAOAgent.log("countRawDangerNearby threw: " + throwable);
        }
        return 0;
    }

    /** [B20] Cook the larder - skill is throughput. */
    public int cookNearbyFood(Object object, int radius, int level) {
        try {
            if (object instanceof IsoPlayer) {
                return com.sao.engine.SAONeeds.cookNearbyFood(
                    (IsoPlayer) object, radius, level);
            }
        } catch (Throwable throwable) {
            SAOAgent.log("cookNearbyFood threw: " + throwable);
        }
        return 0;
    }

    /** [B20] How much of a sound survives the sky right now - the
     *  scanner's own number, so the cry and the scan cannot drift. */
    public float weatherHearing() {
        try {
            return com.sao.engine.SAOPerceptionScanner.weatherHearing();
        } catch (Throwable throwable) {
            SAOAgent.log("weatherHearing threw: " + throwable);
        }
        return 1.0f;
    }

    /** [B6] True while the county's taps still run. */
    public boolean countyWaterOn() {
        return com.sao.engine.SAONeeds.countyWaterOn();
    }

    /** [B19] Appraise the motor pool - what can actually be
     *  driven, not what happens to be parked. */
    public String appraiseVehiclesNear(Object object, int radius) {
        try {
            if (object instanceof IsoPlayer) {
                return com.sao.engine.SAONeeds.appraiseVehiclesNear(
                    (IsoPlayer) object, radius);
            }
        } catch (Throwable throwable) {
            SAOAgent.log("appraiseVehiclesNear threw: " + throwable);
        }
        return "";
    }

    /** [A28] Read the larder - a pure count, nothing moves. */
    public int countEdibleNearby(Object object, int radius) {
        try {
            if (object instanceof IsoPlayer) {
                return com.sao.engine.SAONeeds.countEdibleNearby(
                    (IsoPlayer) object, radius);
            }
        } catch (Throwable throwable) {
            SAOAgent.log("countEdibleNearby threw: " + throwable);
        }
        return 0;
    }

    public String giveItem(Object object, String fullType) {
        try {
            if (!(object instanceof SAOIsoPlayerShell shell)) {
                return "NOT_A_SHELL";
            }
            return com.sao.engine.SAOEquipment.addItem(shell, fullType);
        } catch (Throwable throwable) {
            SAOAgent.log("giveItem threw: " + throwable);
            return "GIVE_FAILED " + throwable;
        }
    }

    /** Movement verbs: the transplanted reference loop. One-line verdicts. */
    public String moveTo(Object object, double x, double y, double z) {
        try {
            if (!(object instanceof SAOIsoPlayerShell shell)) {
                return "NOT_A_SHELL";
            }
            return SAOMovement.begin(shell, routeState(shell), (int) x, (int) y, (int) z);
        } catch (Throwable throwable) {
            SAOAgent.log("moveTo threw: " + throwable);
            return "MOVE_FAILED " + throwable;
        }
    }

    public String moveToPaced(Object object, double x, double y, double z, boolean running) {
        try {
            if (!(object instanceof SAOIsoPlayerShell shell)) {
                return "NOT_A_SHELL";
            }
            return SAOMovement.begin(shell, routeState(shell), (int) x, (int) y, (int) z, running);
        } catch (Throwable throwable) {
            SAOAgent.log("moveToPaced threw: " + throwable);
            return "MOVE_FAILED " + throwable;
        }
    }

    public String tickMove(Object object) {
        try {
            if (!(object instanceof SAOIsoPlayerShell shell)) {
                return "NOT_A_SHELL";
            }
            return SAOMovement.tick(shell, routeState(shell));
        } catch (Throwable throwable) {
            SAOAgent.log("tickMove threw: " + throwable);
            return "TICK_FAILED " + throwable;
        }
    }

    /** [C4] Follow recovery: work the one edge toward a close target
     * the pathfinder cannot route to - the window the player climbed,
     * the fence they hopped. Returns the transition verdict. */
    public String followTraverse(Object object, double tx, double ty) {
        try {
            if (!(object instanceof SAOIsoPlayerShell shell)) {
                return "NOT_A_SHELL";
            }
            return SAOMovement.traverseToward(shell, routeState(shell),
                (int) Math.floor(tx), (int) Math.floor(ty));
        } catch (Throwable throwable) {
            SAOAgent.log("followTraverse threw: " + throwable);
            return "TRAVERSE_FAILED " + throwable;
        }
    }

    /** [C4] The nearest vehicle worth walking to: closest to (cx,cy)
     * with an installed, free, non-driver seat, as "x@y@z@dist" or
     * empty. */
    public String nearestBoardableVehicle(Object object, double cx,
            double cy, double radius) {
        try {
            if (!(object instanceof SAOIsoPlayerShell shell)) {
                return "";
            }
            return com.sao.engine.SAONeeds.nearestBoardableVehicle(
                shell, (float) cx, (float) cy, (float) radius);
        } catch (Throwable throwable) {
            SAOAgent.log("nearestBoardableVehicle threw: " + throwable);
            return "";
        }
    }

    /** Grants or revokes forced entry (window smash) for the current route.
     * The composition decides; execution only obeys. */
    public boolean setForceEntry(Object object, boolean allowed) {
        if (!(object instanceof SAOIsoPlayerShell shell)) {
            return false;
        }
        routeState(shell).mayForceEntry = allowed;
        return true;
    }

    public String cancelMove(Object object) {
        try {
            if (!(object instanceof SAOIsoPlayerShell shell)) {
                return "NOT_A_SHELL";
            }
            return SAOMovement.cancel(shell, routeState(shell));
        } catch (Throwable throwable) {
            SAOAgent.log("cancelMove threw: " + throwable);
            return "CANCEL_FAILED " + throwable;
        }
    }

    private SAOBridge() {
    }

    /** A square a person can actually stand on, at or spiraling out from
     * the requested tile. Dormant drift ignores geometry by design ([A11]);
     * this is where the abstraction is caught before it leaks a body into
     * a wall or a river. Same-floor ring search, radius 6. */
    private static IsoGridSquare findStandableNear(
        zombie.iso.IsoCell cell, int x, int y, int z) {
        for (int ring = 0; ring <= 6; ring++) {
            for (int dy = -ring; dy <= ring; dy++) {
                for (int dx = -ring; dx <= ring; dx++) {
                    if (Math.max(Math.abs(dx), Math.abs(dy)) != ring) {
                        continue;
                    }
                    try {
                        IsoGridSquare candidate = cell.getGridSquare(x + dx, y + dy, z);
                        if (candidate != null
                            && candidate.isFree(false)
                            && !candidate.isSolid()
                            && !candidate.isWaterSquare()) {
                            return candidate;
                        }
                    } catch (Throwable ignored) {
                    }
                }
            }
        }
        return null;
    }

    /** [B43] Which jar is actually loaded.
     *
     *  This returned a hardcoded "0.1.0.0-pre-alpha+java2" while the
     *  repository VERSION said 0.6.0.0-pre-alpha, and it was the ONE
     *  public bridge method no Lua ever called - so the drift was
     *  invisible in both directions at once. [B33] is why that matters:
     *  the shipped jar was two days stale and missing seventeen engine
     *  classes, deploy overwrote it on the way to the game, and the
     *  defect could not be seen from inside a play session at all.
     *
     *  Stamped from VERSION by tools/build-java.sh now, so it cannot be
     *  typed wrong, and read by the Lua so the county can say what it
     *  is running. */
    /** [C29] Set a body's size. Only SAO's own shells carry one; the
     *  scale is held to SAOBodyScale's range and applied on the render
     *  path by the woven advice from the next frame on. Returns
     *  "scale=<held value>" or "NOT_A_SHELL". */
    public String setBodyScale(Object object, double scale) {
        try {
            if (!(object instanceof com.sao.engine.SAOIsoPlayerShell shell)) {
                return "NOT_A_SHELL";
            }
            float held = com.sao.agent.SAOBodyScale.clamp((float) scale);
            shell.bodyScale = held;
            return "scale=" + held;
        } catch (Throwable throwable) {
            return "THREW:" + throwable;
        }
    }

    /** [C31] The pace a body learns at, held on the shell; clamped so
     *  a child never learns nothing and nobody learns faster than an
     *  adult. Never throws (the [C29] gate finding: no net, no method). */
    public String setXpScale(Object object, double scale) {
        try {
            if (!(object instanceof com.sao.engine.SAOIsoPlayerShell shell)) {
                return "NOT_A_SHELL";
            }
            float held = (float) scale;
            if (Float.isNaN(held) || held <= 0f) {
                held = 1f;
            }
            if (held < 0.05f) {
                held = 0.05f;
            }
            if (held > 1f) {
                held = 1f;
            }
            shell.xpScale = held;
            return "learns at " + held;
        } catch (Throwable throwable) {
            return "THREW:" + throwable;
        }
    }

    /** [C32] Dementia's day (Neurodiverse Traits' Alzheimer's, CREDITS.md):
     *  every skill with a level, except the passive and agility families
     *  the mod also leaves alone, has the given chance of losing the
     *  given share of the next level's experience; a level whose
     *  experience falls under its own floor is lost through the engine's
     *  LoseLevel. Seeded from the person and the day so two sessions
     *  agree. Returns how many skills forgot something, -1 when the body
     *  is not ours; never throws. */
    public int loseSkillMemory(Object object, double share, int chancePercent, long seed) {
        try {
            if (!(object instanceof com.sao.engine.SAOIsoPlayerShell shell)) {
                return -1;
            }
            java.util.Random roll = new java.util.Random(seed);
            int forgot = 0;
            for (zombie.characters.skills.PerkFactory.Perk perk
                    : zombie.characters.skills.PerkFactory.PerkList) {
                if (perk == null) {
                    continue;
                }
                zombie.characters.skills.PerkFactory.Perk parent = perk.getParent();
                if (parent == null
                    || parent == zombie.characters.skills.PerkFactory.Perks.None
                    || parent == zombie.characters.skills.PerkFactory.Perks.Passiv
                    || parent == zombie.characters.skills.PerkFactory.Perks.Agility) {
                    continue;
                }
                int level = shell.getPerkLevel(perk);
                float xp = shell.getXp().getXP(perk);
                if (level <= 0 || xp <= 0f) {
                    continue;
                }
                if (roll.nextInt(100) >= chancePercent) {
                    continue;
                }
                float loss = perk.getXpForLevel(level + 1) * (float) share;
                if (loss <= 0f) {
                    continue;
                }
                shell.getXp().AddXP(perk, -loss);
                if (shell.getXp().getXP(perk) < perk.getTotalXpForLevel(level)) {
                    shell.LoseLevel(perk);
                }
                forgot++;
            }
            return forgot;
        } catch (Throwable throwable) {
            SAOAgent.log("loseSkillMemory threw: " + throwable);
            return -1;
        }
    }

    /** [C31] The pace a body learns at; 1 for anything that is not ours. */
    public double getXpScale(Object object) {
        try {
            if (object instanceof com.sao.engine.SAOIsoPlayerShell shell) {
                return shell.xpScale;
            }
            return 1.0;
        } catch (Throwable throwable) {
            return 1.0;
        }
    }

    /** [C29] The size a body holds; 1 for anything that is not ours. */
    public double getBodyScale(Object object) {
        try {
            if (object instanceof com.sao.engine.SAOIsoPlayerShell shell) {
                return shell.bodyScale;
            }
            return 1.0;
        } catch (Throwable throwable) {
            return 1.0;
        }
    }

    /** [C29] The weave's state and the scaler's counters, for the
     *  harness and the receipt: "weave=..|target=..|calls=..|scaled=..". */
    /** [C36] The save day the record's day 0 falls on, from the engine's
     *  own start date; a large negative sentinel when the clock is not
     *  there, which the Lua side treats as "not now". */
    public int recordStartDay() {
        try {
            // [C43] Shifted, the record's day 0 is the lead-in itself:
            // the outbreak lands that many days into the save, wherever
            // in the year it began.
            if (com.sao.engine.SAORecord.isShifted()) {
                return com.sao.engine.SAORecord.leadInApplied();
            }
            int[] start = com.sao.engine.SAORecord.saveStart();
            if (start == null) {
                return -100000;
            }
            return com.sao.engine.SAORecord.startDayFor(start[0], start[1], start[2]);
        } catch (Throwable throwable) {
            return -100000;
        }
    }

    /** [C36] Days since the record's own day 0, today. */
    public int recordDayToday() {
        try {
            int[] today = com.sao.engine.SAORecord.today();
            if (today == null) {
                return -100000;
            }
            return com.sao.engine.SAORecord.recordDayOf(today[0], today[1], today[2]);
        } catch (Throwable throwable) {
            return -100000;
        }
    }

    /** [C43] Place the record's timeline against this save: its own
     *  first day on the save's start day, so the ordinary county it
     *  already carries plays out and then the outbreak arrives.
     *  Refused, and 0, for a save that does not begin before the
     *  record does. */
    public int shiftRecord() {
        try {
            return com.sao.engine.SAORecord.shiftTo();
        } catch (Throwable throwable) {
            return 0;
        }
    }

    /** [C45] The days of history a save begins with behind it. */
    public int daysBehindAtStart() {
        try {
            return com.sao.engine.SAORecord.daysBehindAtStart();
        } catch (Throwable throwable) {
            return -1;
        }
    }

    /** [C43] Back to the shipped calendar. */
    public void anchorRecord() {
        try {
            com.sao.engine.SAORecord.anchor();
        } catch (Throwable ignored) {
        }
    }

    /** [C36] Re-key every vanilla channel to start on the save day; the
     *  count, or -1. */
    public int rekeyRecord(double startDay) {
        try {
            return com.sao.engine.SAORecord.rekeyRadio((int) startDay);
        } catch (Throwable throwable) {
            return -1;
        }
    }

    /** [C36] Every paper in a container dated to today: "keyed=n removed=m". */
    public String keyNewspapers(Object container) {
        try {
            if (!(container instanceof zombie.inventory.ItemContainer box)) {
                return "";
            }
            int[] today = com.sao.engine.SAORecord.today();
            if (today == null) {
                return "";
            }
            return com.sao.engine.SAORecord.keyContainer(box, today[0], today[1], today[2]);
        } catch (Throwable throwable) {
            return "";
        }
    }

    /** [C36] The record's state, for the harness and the log. */
    /** [C38] The county's date for a world-age hour, in a person's
     *  words ("July 12, 1993"); "" off the clock. */
    public String countyDate(double hours) {
        try {
            int[] start = com.sao.engine.SAORecord.saveStart();
            if (start == null) {
                return "";
            }
            return com.sao.engine.SAORecord.countyDate(start[0], start[1], start[2], hours);
        } catch (Throwable throwable) {
            return "";
        }
    }

    /** [C38] The record's own first day, in the same words. */
    public String recordDayZero() {
        try {
            return com.sao.engine.SAORecord.recordDayZero();
        } catch (Throwable throwable) {
            return "";
        }
    }

    public String recordReport() {
        try {
            int[] today = com.sao.engine.SAORecord.today();
            String day = today == null ? "?" : String.valueOf(
                com.sao.engine.SAORecord.recordDayOf(today[0], today[1], today[2]));
            String knews = today == null ? "?" : String.valueOf(com.sao.engine.SAORecord.issueFor(
                zombie.scripting.objects.Newspaper.KNOX_KNEWS, today[0], today[1], today[2]));
            String herald = today == null ? "?" : String.valueOf(com.sao.engine.SAORecord.issueFor(
                zombie.scripting.objects.Newspaper.KENTUCKY_HERALD, today[0], today[1], today[2]));
            return "record day " + day + "; start day " + recordStartDay()
                + "; county paper " + knews + "; Herald " + herald + "; "
                + com.sao.engine.SAORecord.report();
        } catch (Throwable throwable) {
            return "THREW:" + throwable;
        }
    }

    /** [C44] Has this person the makings of a barricade on them - a
     *  hammer, a plank and two nails - anywhere in their inventory? */
    public boolean carriesTheMakings(Object object) {
        return object instanceof zombie.characters.IsoGameCharacter person
            && com.sao.engine.SAOBuild.carriesTheMakings(person);
    }

    /** [C44] The nearest window or door inside the given box that
     *  could take another plank: "x,y,z", or "". */
    public String findBoardable(Object object, double minX, double minY,
                                double maxX, double maxY, double z,
                                double reach) {
        if (object instanceof zombie.characters.IsoGameCharacter person) {
            return com.sao.engine.SAOBuild.findBoardable(person, (int) minX,
                (int) minY, (int) maxX, (int) maxY, (int) z, (int) reach);
        }
        return "";
    }

    /** [C44] Put one plank on it, paid for out of their own bag. The
     *  plank count now on it, or 0 when nothing happened. */
    public int boardWindow(Object object, double x, double y, double z) {
        if (object instanceof zombie.characters.IsoGameCharacter person) {
            com.sao.engine.SAOBuild.readyToBoard(person);
            return com.sao.engine.SAOBuild.board(person, (int) x, (int) y, (int) z);
        }
        return 0;
    }

    /** [C46] Look at the ground a claim stands on, loading its chunks
     *  off disk where the world does not already hold them, and
     *  letting them go again. Writes nothing. */
    public String surveyClaim(double minX, double minY, double maxX,
                              double maxY, double z) {
        try {
            return com.sao.engine.SAOGround.surveyClaim((int) minX, (int) minY,
                (int) maxX, (int) maxY, (int) z);
        } catch (Throwable throwable) {
            return "";
        }
    }

    /** [C47] What a person may put in a fact position, from their own
     *  claims: "field:v1|v2" lines. This is the vocabulary a speaker
     *  is handed, and it is the whole of what it can say. */
    public String speechVocabulary(String claims) {
        try {
            return com.sao.engine.SAOFence.vocabulary(claims);
        } catch (Throwable throwable) {
            return "";
        }
    }

    /** [C47] Anything in a proposed filling this person could not have
     *  said. Empty means the sentence is theirs to say. */
    public String speechViolations(String claims, String filling) {
        try {
            return com.sao.engine.SAOFence.violations(claims, filling);
        } catch (Throwable throwable) {
            // A fence that throws must refuse, never permit.
            return filling == null ? "" : filling;
        }
    }

    /** [C47] How much this person can say at all. */
    public String speechMeasure(String claims) {
        try {
            return com.sao.engine.SAOFence.measure(claims);
        } catch (Throwable throwable) {
            return "";
        }
    }

    public String bodyScaleReport() {
        try {
            return com.sao.agent.SAOBodyScaleWeave.report() + "|"
                + com.sao.agent.SAOBodyScale.report();
        } catch (Throwable throwable) {
            return "THREW:" + throwable;
        }
    }

    public String getVersion() {
        return com.sao.SAOVersion.VALUE;
    }

    /** [C17] How many bodies the pool has taken this session - the
     * crowd ledger's raw feed (DR-021's state agreement between the
     * pool-taking and the presence layer). Monotonic per session;
     * durable accounting is Lua's. */
    private static int poolTaken;

    public int poolTakenCount() {
        return poolTaken;
    }

    /** [B21] Take one of the dead back before adding one of the
     *  living. The operator's directive: the map already carries a
     *  budgeted number of zombies, so a survivor should come OUT of
     *  that number rather than on top of it.
     *
     *  Reach is deliberately short. Clearing a wide radius around
     *  every spawn would quietly empty neighbourhoods, which is a far
     *  larger change than the one asked for. Returns true when the
     *  population was actually paid for. */
    private static boolean takeFromThePool(IsoCell cell, int x, int y, int z,
        int reach) {
        try {
            java.util.ArrayList<zombie.characters.IsoZombie> dead =
                cell.getZombieList();
            if (dead == null) return false;
            zombie.characters.IsoZombie nearest = null;
            float bestD = (float) reach * reach;
            for (int i = 0; i < dead.size(); i++) {
                zombie.characters.IsoZombie zed = dead.get(i);
                if (zed == null) continue;
                if ((int) zed.getZ() != z) continue;
                // [C9] Never delete what carries a person. The zombie
                // list holds living neighbours (DR-009), risen players,
                // and the county's own marked dead ([C8]) alongside the
                // fungible crowd; only the crowd is the pool. The
                // predicate fails closed - unreadable means spared.
                if (com.sao.engine.SAOKnox.identityBearing(zed)) continue;
                float ddx = zed.getX() - x, ddy = zed.getY() - y;
                float d2 = ddx * ddx + ddy * ddy;
                if (d2 <= bestD) {
                    bestD = d2;
                    nearest = zed;
                }
            }
            if (nearest == null) return false;
            nearest.removeFromWorld();
            // [C17] The crowd ledger's source: every body the pool takes
            // is counted, session-monotonic; the Lua ledger folds the
            // deltas into the durable store (DR-021's state agreement).
            poolTaken++;
            return true;
        } catch (Throwable throwable) {
            SAOAgent.log("takeFromThePool threw: " + throwable);
            return false;
        }
    }

    public IsoPlayer spawnShellNamed(String forename, String surname, double dx, double dy, double dz) {
        try {
            IsoWorld world = IsoWorld.instance;
            IsoCell cell = world == null ? null : world.getCell();
            if (cell == null) {
                SAOAgent.log("spawn refused: no world cell");
                return null;
            }
            int x = (int) dx;
            int y = (int) dy;
            int z = (int) dz;
            IsoGridSquare square = findStandableNear(cell, x, y, z);
            if (square == null) {
                SAOAgent.log("spawn refused: no standable square near " + x + "," + y + "," + z);
                return null;
            }
            if (square.getX() != x || square.getY() != y) {
                SAOAgent.log("spawn nudged from " + x + "," + y
                    + " to " + square.getX() + "," + square.getY()
                    + " (record square unusable)");
                x = square.getX();
                y = square.getY();
            }
            // [B21] A life instead of a corpse. If nothing is in
            // reach the survivor still exists - the census decides
            // WHO lives here; this decides what it costs.
            if (takeFromThePool(cell, x, y, z, 12)) {
                SAOAgent.log("taken from the pool: " + forename + " "
                    + surname + " stands where one of the dead did");
            } else {
                SAOAgent.log("no dead in reach of " + x + "," + y
                    + " - " + forename + " " + surname
                    + " is added, not exchanged");
            }

            SurvivorDesc desc = SurvivorFactory.CreateSurvivor();
            if (desc == null) {
                SAOAgent.log("spawn refused: CreateSurvivor returned null");
                return null;
            }
            // [C3] "Unnamed"/"Survivor" are Identity's placeholders, not a
            // name. Stamping them here destroyed the engine's generated name
            // one call before backfillName existed to read it - every native
            // record was "Unnamed Survivor" forever. A placeholder never
            // overwrites; a real name always does.
            if (forename != null && !"Unnamed".equals(forename)) {
                desc.setForename(forename);
            }
            if (surname != null && !"Survivor".equals(surname)) {
                desc.setSurname(surname);
            }

            IsoPlayer[] slotsBefore = IsoPlayer.players.clone();

            SAOIsoPlayerShell shell = new SAOIsoPlayerShell(cell, desc, x, y, z);
            shell.setNpc(true);
            shell.remote = false;
            shell.playerIndex = allocateOffSlotIndex();
            shell.serverPlayerIndex = -1;
            shell.setOnlineID((short) -1);
            String shownName = desc.getForename() == null
                ? "Survivor" : desc.getForename();
            shell.setUsername(shownName);
            shell.setGhostMode(false);

            shell.setCurrent(square);
            shell.setMovingSquareNow();
            shell.setZombiesDontAttack(false);
            shell.setAlphaAndTarget(1.0f);
            cell.addMovingObject(shell);
            ModelManager.instance.Add(shell);

            if (!sameSlots(slotsBefore, IsoPlayer.players)) {
                SAOAgent.log("SLOT VIOLATION during spawn - rolling back");
                removeShellInternal(shell);
                return null;
            }

            clearMovementIntent(shell);
            SAOAgent.log("shell up at " + x + "," + y + "," + z
                + " playerIndex=" + shell.playerIndex
                + " for " + forename + " " + surname);
            return shell;
        } catch (Throwable throwable) {
            SAOAgent.log("spawnShellNamed threw: " + throwable);
            return null;
        }
    }

    public boolean removeShell(Object object) {
        if (!(object instanceof SAOIsoPlayerShell shell)) {
            SAOAgent.log("removeShell refused: not an SAO shell");
            return false;
        }
        try {
            removeShellInternal(shell);
            SAOAgent.log("shell removed");
            return true;
        } catch (Throwable throwable) {
            SAOAgent.log("removeShell threw: " + throwable);
            return false;
        }
    }

    public boolean isShell(Object object) {
        return object instanceof SAOIsoPlayerShell;
    }

    // ------------------------------------------------------------------

    private static void removeShellInternal(SAOIsoPlayerShell shell) {
        try {
            clearMovementIntent(shell);
        } catch (Throwable ignored) {
            // teardown continues regardless
        }
        ModelManager.instance.Remove((IsoGameCharacter) shell);
        shell.setMovingSquare(null);
        shell.removeFromWorld();
    }

    /**
     * Index 0 owns the system cursor (updateCursorVisibility hides it while
     * aiming for playerIndex 0), so an NPC must never sit there. First free
     * slot above 0, else 1.
     */
    private static int allocateOffSlotIndex() {
        IsoPlayer[] players = IsoPlayer.players;
        for (int index = 1; index < players.length; index++) {
            if (players[index] == null) {
                return index;
            }
        }
        return 1;
    }

    private static boolean sameSlots(IsoPlayer[] before, IsoPlayer[] after) {
        if (before.length != after.length) {
            return false;
        }
        for (int index = 0; index < before.length; index++) {
            if (before[index] != after[index]) {
                return false;
            }
        }
        return true;
    }

    /**
     * Zero every movement input the engine could consume. An early body
     * wandered on its own because playerMoveDir and the AI control vars were
     * never explicitly zeroed after construction.
     */
    private static void clearMovementIntent(SAOIsoPlayerShell shell) {
        shell.playerMoveDir.x = 0.0f;
        shell.playerMoveDir.y = 0.0f;
        shell.setJustMoved(false);

        for (ECSComponent component : shell.getECSComponentMap().values()) {
            if (component instanceof AIComponent ai) {
                var vars = ai.getHumanControlVars();
                if (vars != null) {
                    vars.justMoved = false;
                    vars.running = false;
                    vars.strafeX = 0.0f;
                    vars.strafeY = 0.0f;
                    vars.aiming = false;
                    vars.melee = false;
                    vars.initiateAttack = false;
                }
            }
        }
    }
}
