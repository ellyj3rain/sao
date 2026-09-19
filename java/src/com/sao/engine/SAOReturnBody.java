package com.sao.engine;

import com.sao.agent.SAOAgent;
import java.util.Arrays;
import java.util.Collections;
import java.util.IdentityHashMap;
import java.util.Map;
import java.util.Set;
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

/** Staged engine representation; the caller owns return authorization and state. */
public final class SAOReturnBody {
    private enum Phase { DETACHED, PUBLISHING, PUBLISHED, ACTIVE, DISCARDING, DISCARDED }

    private static final class Stage {
        final IsoCell cell;
        Phase phase = Phase.DETACHED;
        IsoGridSquare square;
        Stage(IsoCell cell) { this.cell = cell; }
    }

    // Completed transactions follow engine ownership. Pending transactions retain
    // their exact shell across Lua reload/GC until activation or confirmed discard.
    private static final Map<SAOIsoPlayerShell, Stage> STAGES = new WeakHashMap<>();
    private static final Set<SAOIsoPlayerShell> PENDING =
        Collections.newSetFromMap(new IdentityHashMap<>());

    private SAOReturnBody() { }

    /** Construct without a square, update-list entry, model, kit or population debit. */
    public static SAOIsoPlayerShell create(String forename, String surname,
            double x, double y, double z, boolean female) {
        SurvivorDesc descriptor = null;
        SAOIsoPlayerShell shell = null;
        try {
            IsoCell cell = IsoWorld.instance == null ? null : IsoWorld.instance.currentCell;
            if (cell == null || !coordinate(x) || !coordinate(y) || !coordinate(z)) return null;
            forgetOtherWorlds(cell);
            descriptor = SurvivorFactory.CreateSurvivor();
            if (descriptor == null) return null;
            // SurvivorFactory registers descriptors immediately; this one is detached.
            IsoGameCharacter.getSurvivorMap().remove(descriptor.getID(), descriptor);
            descriptor.setFemale(female);
            SurvivorFactory.setTorso(descriptor);
            if (forename != null) descriptor.setForename(forename);
            if (surname != null) descriptor.setSurname(surname);
            IsoPlayer[] slots = IsoPlayer.players.clone();
            // B42.20 IsoGameCharacter's constructor registers ANY nonzero position,
            // even with a null cell. All-zero construction is the detached seam.
            shell = new SAOIsoPlayerShell(null, descriptor, 0, 0, 0);
            STAGES.put(shell, new Stage(cell));
            PENDING.add(shell);
            shell.removalPending = true;
            shell.populationAccounted = true;
            shell.setNpc(true);
            shell.remote = false;
            shell.playerIndex = offSlotIndex();
            shell.serverPlayerIndex = -1;
            shell.setOnlineID((short) -1);
            shell.setUsername(descriptor.getForename() == null ? "Survivor" : descriptor.getForename());
            position(shell, (float) x, (float) y, (float) z);
            shell.setGhostMode(true);
            shell.setZombiesDontAttack(true);
            shell.setAlphaAndTarget(0.0f);
            clearMovement(shell);
            if (!Arrays.equals(slots, IsoPlayer.players)
                    || cell.getObjectList().contains(shell) || cell.getAddList().contains(shell)
                    || shell.getCurrentSquare() != null || shell.isAddedToModelManager()) {
                throw new IllegalStateException("Detached shell was published by construction");
            }
            return shell;
        } catch (Throwable error) {
            SAOAgent.log("return body creation failed: " + error);
            if (shell != null) {
                shell.removalPending = true;
                // Return the exact cleanup handle if native removal is deferred or
                // fails. DISCARDING shells cannot publish or activate.
                if (!discard(shell)) return shell;
            }
            if (descriptor != null) IsoGameCharacter.getSurvivorMap().remove(descriptor.getID(), descriptor);
            return null;
        }
    }

    /** Recover the existing transaction after Lua reload; ambiguity is an error. */
    public static SAOIsoPlayerShell find(String personId, String token) {
        if (personId == null || personId.isEmpty() || token == null || token.isEmpty()) return null;
        IsoCell cell = IsoWorld.instance.currentCell;
        forgetOtherWorlds(cell);
        SAOIsoPlayerShell found = null;
        for (Map.Entry<SAOIsoPlayerShell, Stage> entry : STAGES.entrySet()) {
            SAOIsoPlayerShell shell = entry.getKey();
            Stage stage = entry.getValue();
            if (shell == null || stage.cell != cell || stage.phase == Phase.DISCARDED) continue;
            if (!personId.equals(shell.getModData().rawget("SAOPersonId"))
                    || !token.equals(shell.getModData().rawget("SAOReturnToken"))) continue;
            if (found != null) throw new IllegalStateException("Duplicate staged return identity/token");
            found = shell;
        }
        return found;
    }

    /** A retained construction/removal failure must complete cleanup before retry. */
    public static boolean needsCleanup(SAOIsoPlayerShell shell) {
        Stage stage = STAGES.get(shell);
        return stage != null && stage.phase == Phase.DISCARDING;
    }

    /** Publish a restored shell once, retaining the pause until activate commits it. */
    public static boolean publish(SAOIsoPlayerShell shell) {
        Stage stage = STAGES.get(shell);
        if (stage == null || stage.phase == Phase.DISCARDING || stage.phase == Phase.DISCARDED
                || IsoWorld.instance.currentCell != stage.cell) return false;
        if (stage.phase == Phase.PUBLISHED || stage.phase == Phase.ACTIVE) return true;
        try {
            shell.removalPending = true;
            if (!ModelManager.instance.isCreated()) return false;
            if (stage.square == null) {
                stage.square = standableNear(stage.cell, (int) Math.floor(shell.getX()),
                    (int) Math.floor(shell.getY()), (int) Math.floor(shell.getZ()));
                if (stage.square == null) return false;
            }
            stage.phase = Phase.PUBLISHING;
            position(shell, stage.square.getX() + 0.5f, stage.square.getY() + 0.5f,
                stage.square.getZ());
            shell.setCurrent(stage.square);
            shell.setMovingSquare(stage.square);
            if (!stage.cell.getObjectList().contains(shell) && !stage.cell.getAddList().contains(shell)) {
                stage.cell.addMovingObject(shell);
            }
            IsoGameCharacter.getSurvivorMap().put(shell.getDescriptor().getID(), shell.getDescriptor());
            if (!shell.isAddedToModelManager()) ModelManager.instance.Add(shell);
            if (!shell.isAddedToModelManager()) return false;
            stage.phase = Phase.PUBLISHED;
            return true;
        } catch (Throwable error) {
            // The caller retains this exact handle for retry or discard.
            SAOAgent.log("return body publication failed: " + error);
            return false;
        }
    }

    /** Release the engine pause only after the caller commits identity and controller. */
    public static boolean activate(SAOIsoPlayerShell shell) {
        Stage stage = STAGES.get(shell);
        if (stage == null || IsoWorld.instance.currentCell != stage.cell) return false;
        if (stage.phase == Phase.ACTIVE) return true;
        if (stage.phase != Phase.PUBLISHED) return false;
        try {
            clearMovement(shell);
            shell.setGhostMode(false);
            shell.setZombiesDontAttack(false);
            shell.setAlphaAndTarget(1.0f);
            SAONativeSnapshot.register(shell);
            shell.removalPending = false;
            stage.phase = Phase.ACTIVE;
            PENDING.remove(shell);
            return true;
        } catch (Throwable error) {
            shell.removalPending = true;
            shell.setGhostMode(true);
            shell.setZombiesDontAttack(true);
            shell.setAlphaAndTarget(0.0f);
            try { SAONativeSnapshot.unregister(shell); }
            catch (Throwable cleanup) { SAOAgent.log("return activation cleanup failed: " + cleanup); }
            SAOAgent.log("return body activation failed: " + error);
            return false;
        }
    }

    /** Keep the paused handle registered here until every removal step has succeeded. */
    public static boolean discard(SAOIsoPlayerShell shell) {
        Stage stage = STAGES.get(shell);
        if (stage == null) return false;
        if (stage.phase == Phase.DISCARDED) return true;
        if (IsoWorld.instance.currentCell != stage.cell) return false;
        stage.phase = Phase.DISCARDING;
        shell.removalPending = true;
        try {
            shell.setGhostMode(true);
            shell.setZombiesDontAttack(true);
            shell.setAlphaAndTarget(0.0f);
            clearMovement(shell);
            SAONativeSnapshot.unregister(shell);
            ModelManager.instance.Remove(shell);
            shell.removeFromSquare();
            shell.removeFromWorld();
            if (stage.cell.getObjectList().contains(shell) || stage.cell.getAddList().contains(shell)
                    || shell.getCurrentSquare() != null || shell.isAddedToModelManager()) return false;
            IsoGameCharacter.getSurvivorMap().remove(shell.getDescriptor().getID(), shell.getDescriptor());
            stage.phase = Phase.DISCARDED;
            PENDING.remove(shell);
            return true;
        } catch (Throwable error) {
            SAOAgent.log("return body discard failed: " + error);
            return false;
        }
    }

    private static void forgetOtherWorlds(IsoCell cell) {
        STAGES.entrySet().removeIf(entry -> entry.getValue().cell != cell);
        PENDING.removeIf(shell -> !STAGES.containsKey(shell));
    }

    private static boolean coordinate(double value) {
        return Double.isFinite(value) && value > Integer.MIN_VALUE + 8.0
            && value < Integer.MAX_VALUE - 8.0;
    }

    private static int offSlotIndex() {
        for (int i = 1; i < IsoPlayer.players.length; i++) {
            if (IsoPlayer.players[i] == null) return i;
        }
        return 1;
    }

    private static void position(SAOIsoPlayerShell shell, float x, float y, float z) {
        shell.setX(x);
        shell.setY(y);
        shell.setZ(z);
        shell.setLastX(x);
        shell.setNextX(x);
        shell.setLastY(y);
        shell.setNextY(y);
    }

    private static IsoGridSquare standableNear(IsoCell cell, int x, int y, int z) {
        for (int ring = 0; ring <= 6; ring++) {
            for (int dy = -ring; dy <= ring; dy++) {
                for (int dx = -ring; dx <= ring; dx++) {
                    if (Math.max(Math.abs(dx), Math.abs(dy)) != ring) continue;
                    IsoGridSquare square = cell.getGridSquare(x + dx, y + dy, z);
                    if (square != null && square.isFree(false)
                            && !square.isSolid() && !square.isWaterSquare()) return square;
                }
            }
        }
        return null;
    }

    private static void clearMovement(SAOIsoPlayerShell shell) {
        shell.playerMoveDir.x = shell.playerMoveDir.y = 0.0f;
        shell.setJustMoved(false);
        for (ECSComponent component : shell.getECSComponentMap().values()) {
            if (component instanceof AIComponent ai) {
                var input = ai.getHumanControlVars();
                if (input == null) continue;
                input.justMoved = input.running = input.aiming = input.melee = input.initiateAttack = false;
                input.strafeX = input.strafeY = 0.0f;
            }
        }
    }
}
