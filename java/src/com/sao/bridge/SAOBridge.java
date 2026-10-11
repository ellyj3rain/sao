package com.sao.bridge;

import com.sao.agent.SAOAgent;
import com.sao.engine.SAODriver;
import com.sao.engine.SAODriveState;
import com.sao.engine.SAODurableText;
import com.sao.engine.SAOIsoPlayerShell;
import com.sao.engine.SAOMovement;
import com.sao.engine.SAORouteState;
import java.util.Map;
import java.util.WeakHashMap;
import java.util.ArrayList;
import java.util.HashMap;
import se.krka.kahlua.vm.LuaClosure;
import zombie.characters.IsoGameCharacter;
import zombie.characters.IsoPlayer;
import zombie.characters.SurvivorDesc;
import zombie.characters.SurvivorFactory;
import zombie.characters.animals.IsoAnimal;
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
    /** [C114] Per-shell driving state, the same lifetime rule as routes. */
    private final Map<SAOIsoPlayerShell, SAODriveState> drives = new WeakHashMap<>();
    /** [C116] Per-crossed-body driving state, the same lifetime rule,
     * keyed on the IsoZombie the sister's controller owns - a separate
     * map so the two entry types can never collide on one key and the
     * survivor's trips are untouched. */
    private final Map<zombie.characters.IsoZombie, SAODriveState> crossedDrives =
        new WeakHashMap<>();
    /** [C82] One bounded daemon owns shadow coordination inference.  It never
     * receives engine objects and never mutates game state. */
    private final com.sao.engine.SAOCoordinationWorker coordinationWorker =
        new com.sao.engine.SAOCoordinationWorker();

    /** Private save-local Week One transaction state; callable by checked server Lua. */
    public String weekOneRetirementPrepare(String token, String personId,
            double id, double born, String accountKey, String playerKey,
            double descriptorId, String forename, String surname,
            String world, String gameMode) {
        return com.sao.engine.SAOWeekOnePrivateStore.retirement("prepare",
            token, personId, id, born, accountKey, playerKey, descriptorId,
            forename, surname, world, gameMode);
    }

    public String weekOneRetirementFinish(String token, String personId,
            double id, double born, String accountKey, String playerKey,
            double descriptorId, String forename, String surname,
            String world, String gameMode) {
        return com.sao.engine.SAOWeekOnePrivateStore.retirement("finish",
            token, personId, id, born, accountKey, playerKey, descriptorId,
            forename, surname, world, gameMode);
    }

    public String weekOneRetirementStatus(String token, String personId,
            double id, double born, String accountKey, String playerKey,
            double descriptorId, String forename, String surname,
            String world, String gameMode) {
        return com.sao.engine.SAOWeekOnePrivateStore.retirement("status",
            token, personId, id, born, accountKey, playerKey, descriptorId,
            forename, surname, world, gameMode);
    }

    public String weekOneReinforcementReserve(String source, String cohort,
            double count, String accountKey, String playerKey,
            double descriptorId, String forename, String surname,
            String world, String gameMode) {
        return com.sao.engine.SAOWeekOnePrivateStore.reinforcement("reserve",
            source, cohort, count, accountKey, playerKey, descriptorId,
            forename, surname, world, gameMode);
    }

    public String weekOneReinforcementStatus(String source, String cohort,
            double count, String accountKey, String playerKey,
            double descriptorId, String forename, String surname,
            String world, String gameMode) {
        return com.sao.engine.SAOWeekOnePrivateStore.reinforcement("status",
            source, cohort, count, accountKey, playerKey, descriptorId,
            forename, surname, world, gameMode);
    }

    public String weekOneReinforcementRelease(String source, String cohort,
            double count, String accountKey, String playerKey,
            double descriptorId, String forename, String surname,
            String world, String gameMode) {
        return com.sao.engine.SAOWeekOnePrivateStore.reinforcement("release",
            source, cohort, count, accountKey, playerKey, descriptorId,
            forename, surname, world, gameMode);
    }

    public String weekOneScenarioReserve(String source, String cohort,
            double ordinal, String accountKey, String playerKey,
            double descriptorId, String forename, String surname,
            String world, String gameMode) {
        return com.sao.engine.SAOWeekOnePrivateStore.scenario("reserve",
            source, cohort, ordinal, accountKey, playerKey, descriptorId,
            forename, surname, world, gameMode);
    }

    public String weekOneScenarioStatus(String source, String cohort,
            double ordinal, String accountKey, String playerKey,
            double descriptorId, String forename, String surname,
            String world, String gameMode) {
        return com.sao.engine.SAOWeekOnePrivateStore.scenario("status",
            source, cohort, ordinal, accountKey, playerKey, descriptorId,
            forename, surname, world, gameMode);
    }

    public String weekOneScenarioRelease(String source, String cohort,
            double ordinal, String accountKey, String playerKey,
            double descriptorId, String forename, String surname,
            String world, String gameMode) {
        return com.sao.engine.SAOWeekOnePrivateStore.scenario("release",
            source, cohort, ordinal, accountKey, playerKey, descriptorId,
            forename, surname, world, gameMode);
    }

    /** Server-verified source body to private owner, returning an opaque public ref. */
    public String weekOneOwnerReceiptPut(String source, double brainId,
            double born, String accountKey, String playerKey,
            double descriptorId, String forename, String surname,
            String world, String gameMode) {
        return com.sao.engine.SAOWeekOnePrivateStore.ownerReceipt("put",
            source, brainId, born, accountKey, playerKey, descriptorId,
            forename, surname, world, gameMode);
    }

    public String weekOneOwnerReceiptGet(String source, double brainId,
            double born, String accountKey, String playerKey,
            double descriptorId, String forename, String surname,
            String world, String gameMode) {
        return com.sao.engine.SAOWeekOnePrivateStore.ownerReceipt("get",
            source, brainId, born, accountKey, playerKey, descriptorId,
            forename, surname, world, gameMode);
    }

    /** Bounded source-table keys; Lua resolves each key against the current table. */
    public se.krka.kahlua.vm.KahluaTable weekOnePollEntries(Object table,
            String stream, int limit) {
        try {
            return com.sao.engine.SAOWeekOnePollCursor.entries(table, stream, limit);
        } catch (Throwable error) {
            SAOAgent.log("weekOnePollEntries refused: " + error);
            return null;
        }
    }

    public boolean weekOnePollReset(String stream) {
        try { return com.sao.engine.SAOWeekOnePollCursor.reset(stream); }
        catch (Throwable error) { return false; }
    }

    /**
     * Find the one installed Week One hit listener that still owns the
     * unqualified Shahid explosion.  Lua deliberately cannot introspect a
     * closure's prototype, so the compatibility patch asks this bridge for
     * the exact callback object before removing it from OnHitZombie.  The
     * patch pins BWOPlayer.lua's bytes; this runtime check refuses a changed
     * callback shape or any ambiguous registration.
     */
    public LuaClosure weekOneSourceHitCallback() {
        try {
            var events = new ArrayList<zombie.Lua.Event>();
            var byName = new HashMap<String, zombie.Lua.Event>();
            zombie.Lua.LuaEventManager.getEvents(events, byName);
            var event = byName.get("OnHitZombie");
            if (event == null || event.callbacks == null) return null;
            LuaClosure found = null;
            for (var callback : event.callbacks) {
                if (callback == null || callback.prototype == null) continue;
                var source = callback.prototype;
                if (!"onHitZombie".equals(source.name) || source.lines == null
                        || source.lines.length == 0 || source.lines[0] != 319) continue;
                if (source.filename != null && !source.filename.replace('\\', '/')
                        .endsWith("/BanditsWeekOne/42.20/media/lua/client/BWOPlayer.lua")) continue;
                if (found != null) return null;
                found = callback;
            }
            return found;
        } catch (Throwable error) {
            SAOAgent.log("weekOneSourceHitCallback refused: " + error);
            return null;
        }
    }

    /**
     * Drop projections owned by the Lua/world environment that just ended.
     * Durable person records and transaction journals live in ModData; none of
     * these body-keyed adapters may cross into the next world in this process.
     */
    void resetRuntimeForWorld() {
        routes.clear();
        combats.clear();
        drives.clear();
        crossedDrives.clear();
        coordinationWorker.resetRuntimeForWorld();
        com.sao.engine.SAOWeekOnePrivateStore.resetRuntimeForWorld();
        com.sao.engine.SAOWeekOnePollCursor.resetRuntimeForWorld();
        com.sao.engine.SAONeeds.resetRuntimeForWorld();
        com.sao.engine.SAOCooking.reset();
        com.sao.engine.SAOReturnBody.resetRuntimeForWorld();
        com.sao.engine.SAOWorldSources.resetRuntimeForWorld();
        com.sao.engine.SAOPerceptionScanner.resetRuntimeForWorld();
        com.sao.engine.SAOAnimalCare.resetRuntimeForWorld();
        com.sao.engine.SAOTabletop.resetRuntimeForWorld();
        com.sao.engine.SAORadioPlayback.resetRuntimeForWorld();
        com.sao.engine.SAODanceCycle.resetRuntimeForWorld();
    }

    /** Exact native-bundle standing.  Lua refuses any hash other than C82's
     * imported Speakeasy artifact before it submits a shadow request. */
    public String coordinationBundleStatus() {
        try {
            return coordinationWorker.status();
        } catch (Throwable throwable) {
            SAOAgent.log("coordinationBundleStatus threw: " + throwable);
            return "REFUSED\tbridge-exception";
        }
    }

    /** Validate one source-reconstructed personal prior before Lua publishes it. */
    public String educationValidate(String rawJson, String rawSha256,
            String personId, String profileSha256, String bankSha256,
            String backgroundsSha256, String personEducationSha256,
            String exposuresSha256, String archiveSha256, double countyTick) {
        try {
            if (rawJson == null || rawJson.length() > 2 * 1024 * 1024) {
                return "SAO_EDUCATION_REFUSED_2\tinput-bound";
            }
            var expected = new com.sao.engine.SAOEducationPrior.Bindings(personId,
                profileSha256, bankSha256, backgroundsSha256,
                personEducationSha256, exposuresSha256, archiveSha256);
            var prior = com.sao.engine.SAOEducationPrior.load(
                rawJson.getBytes(java.nio.charset.StandardCharsets.UTF_8),
                rawSha256, expected, countyTick);
            return prior.snapshotWire(countyTick);
        } catch (Throwable throwable) {
            SAOAgent.log("educationValidate refused: " + throwable);
            return "SAO_EDUCATION_REFUSED_2\tinvalid-source-prior";
        }
    }

    /** A detached conceptual projection; no native skill, claim or learning write. */
    public String educationQuery(String rawJson, String rawSha256,
            String personId, String profileSha256, String bankSha256,
            String backgroundsSha256, String personEducationSha256,
            String exposuresSha256, String archiveSha256, double countyTick) {
        return educationValidate(rawJson, rawSha256, personId, profileSha256,
            bankSha256, backgroundsSha256, personEducationSha256,
            exposuresSha256, archiveSha256, countyTick);
    }

    /** Decode the prior's bounded ASCII wire field through strict UTF-8. */
    public String educationDecode(String escaped) {
        try {
            return com.sao.engine.SAOEducationPrior.decodeWireField(escaped);
        } catch (Throwable throwable) {
            return null;
        }
    }

    public boolean educationCheckConcept(String conceptRefJson, String courseUnitsJson,
            String conceptId, String sourceId, String sourceVersion, String sourcePath,
            String sourceSha256, String exerciseId) {
        try {
            return com.sao.engine.SAOEducationPrior.checkConceptView(conceptRefJson,
                courseUnitsJson, conceptId, sourceId, sourceVersion, sourcePath,
                sourceSha256, exerciseId);
        } catch (Throwable error) { return false; }
    }

    /** Preserve verified source bytes through native Kahlua string serialization. */
    public Object educationPack(String rawJson) {
        try {
            if (rawJson == null || rawJson.length() > 2 * 1024 * 1024
                    || rawJson.getBytes(java.nio.charset.StandardCharsets.UTF_8).length > 2 * 1024 * 1024) {
                return null;
            }
            return SAODurableText.pack(rawJson);
        } catch (Throwable throwable) {
            SAOAgent.log("educationPack refused: " + throwable);
            return null;
        }
    }

    /** Unpack source bytes without admitting a prior or changing a person. */
    public String educationUnpack(Object packed) {
        try {
            if (packed instanceof se.krka.kahlua.vm.KahluaTable table) {
                Object declared = table.rawget("bytes");
                if (!(declared instanceof Double length) || !Double.isFinite(length)
                        || length < 1 || length > 2 * 1024 * 1024) return null;
            } else if (!(packed instanceof String text) || text.length() > 2 * 1024 * 1024) {
                return null;
            }
            String text = SAODurableText.unpack(packed);
            return text.getBytes(java.nio.charset.StandardCharsets.UTF_8).length <= 2 * 1024 * 1024
                ? text : null;
        } catch (Throwable throwable) {
            SAOAgent.log("educationUnpack refused: " + throwable);
            return null;
        }
    }

    /** Validate a complete source-produced registry before Lua stages any row. */
    public String educationCheckedRegistry(String rawJson, String rawSha256,
            String worldSha256, String bankSha256, String archiveSha256, double countyTick) {
        try {
            if (rawJson == null || rawJson.length() > com.sao.engine.SAOEducationPrior.MAX_REGISTRY_BYTES)
                return null;
            return com.sao.engine.SAOEducationPrior.checkedRegistry(
                rawJson.getBytes(java.nio.charset.StandardCharsets.UTF_8), rawSha256,
                worldSha256, bankSha256, archiveSha256, countyTick);
        } catch (Throwable error) { return null; }
    }

    public String educationRegistryDecode(String encoded) {
        try { return com.sao.engine.SAOEducationPrior.decodeRegistryField(encoded); }
        catch (Throwable error) { return null; }
    }

    public Object educationRegistryPack(String rawJson) {
        try {
            int maximum = com.sao.engine.SAOEducationPrior.MAX_REGISTRY_BYTES;
            if (rawJson == null || rawJson.length() > maximum
                    || rawJson.getBytes(java.nio.charset.StandardCharsets.UTF_8).length > maximum) return null;
            return SAODurableText.pack(rawJson);
        } catch (Throwable error) { return null; }
    }

    public String educationRegistryUnpack(Object packed) {
        try {
            int maximum = com.sao.engine.SAOEducationPrior.MAX_REGISTRY_BYTES;
            if (packed instanceof se.krka.kahlua.vm.KahluaTable table) {
                Object declared = table.rawget("bytes");
                if (!(declared instanceof Double length) || !Double.isFinite(length)
                        || length < 1 || length > maximum) return null;
            } else if (!(packed instanceof String text) || text.length() > maximum) return null;
            String text = SAODurableText.unpack(packed);
            return text.getBytes(java.nio.charset.StandardCharsets.UTF_8).length <= maximum ? text : null;
        } catch (Throwable error) { return null; }
    }

    /** Queue an immutable, non-authoritative recipient-decision snapshot. */
    public String submitCoordinationShadow(String requestId, String canonicalJson,
            String typedFeaturesCsv, String feasibleOptionsCsv) {
        try {
            return coordinationWorker.submit(requestId, canonicalJson,
                typedFeaturesCsv, feasibleOptionsCsv);
        } catch (Throwable throwable) {
            SAOAgent.log("submitCoordinationShadow threw: " + throwable);
            return "REFUSED\tbridge-exception";
        }
    }

    /** Return PENDING/MISSING or one completed result.  Calling Lua performs
     * current process, response, option and execution-owner revalidation. */
    public String pollCoordinationShadow(String requestId) {
        try {
            return coordinationWorker.poll(requestId);
        } catch (Throwable throwable) {
            SAOAgent.log("pollCoordinationShadow threw: " + throwable);
            return "FAILED\tbridge-exception";
        }
    }

    /** Cancel one living person's obsolete shadow without touching another. */
    public String cancelCoordinationShadow(String requestId) {
        try {
            return coordinationWorker.cancel(requestId);
        } catch (Throwable throwable) {
            SAOAgent.log("cancelCoordinationShadow threw: " + throwable);
            return "REFUSED\tbridge-exception";
        }
    }

    public int coordinationShadowPendingCount() {
        try {
            return coordinationWorker.pendingCount();
        } catch (Throwable throwable) {
            return -1;
        }
    }

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
                    || zombie.isUseless()
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
                    || person instanceof IsoAnimal || person == shell
                    || person.isDead()) {
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
            if (chr instanceof SAOIsoPlayerShell shell) {
                if (com.sao.engine.SAONativeDeath.hasCorpse(shell)) {
                    return com.sao.engine.SAONativeDeath.isDetached(shell) ? "ALREADY_CORPSE" : "DIE_PENDING";
                }
                // An unloaded square, a failed native die(), or a network
                // handoff alone cannot acknowledge this shell's corpse.
                if (shell.getCurrentSquare() == null) return "DIE_PENDING";
                shell.die();
                return com.sao.engine.SAONativeDeath.isDetached(shell) ? "DIED" : "DIE_PENDING";
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

    /** Bounded combat: exact actor-admitted sight key, no nearest replacement. */
    public String combatOpportunity(Object object, String kind, String key) {
        try {
            return object instanceof SAOIsoPlayerShell shell
                ? com.sao.engine.SAOCombat.opportunity(shell, kind, key) : "REFUSED\tbody-unavailable";
        } catch (Throwable error) {
            SAOAgent.log("combatOpportunity threw: " + error);
            return "REFUSED\tnative-unavailable";
        }
    }

    public String localCombatMoves(Object object) {
        try {
            return object instanceof SAOIsoPlayerShell shell
                ? com.sao.engine.SAOCombat.localMoves(shell) : "REFUSED\tbody-unavailable";
        } catch (Throwable error) {
            SAOAgent.log("localCombatMoves threw: " + error);
            return "REFUSED\tnative-unavailable";
        }
    }

    public String beginCombatObserved(Object object, String kind, String key, String mode) {
        try {
            if (!(object instanceof SAOIsoPlayerShell shell)) return "COMBAT_FAILED BODY_UNAVAILABLE";
            var combat = combats.computeIfAbsent(shell, ignored -> new com.sao.engine.SAOCombat());
            return combat.beginObserved(shell, kind, key, mode);
        } catch (Throwable error) {
            SAOAgent.log("beginCombatObserved threw: " + error);
            return "COMBAT_FAILED NATIVE_UNAVAILABLE";
        }
    }

    public String cancelCombatObserved(Object object) {
        try {
            if (!(object instanceof SAOIsoPlayerShell shell)) return "COMBAT_FAILED BODY_UNAVAILABLE";
            var combat = combats.get(shell);
            if (combat == null) return "COMBAT_CANCELLED";
            if (!combat.isBounded()) return combat.hasCommitment() ? "COMBAT_HELD" : "COMBAT_CANCELLED";
            return combat.cancelObserved();
        } catch (Throwable error) {
            SAOAgent.log("cancelCombatObserved threw: " + error);
            return "COMBAT_HELD";
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
                var combat = combats.get(shell);
                if (combat != null) {
                    if (combat.isBounded() && "COMBAT_HELD".equals(combat.cancelObserved()))
                        return "COMBAT_HELD";
                    combat.reset();
                    combats.remove(shell, combat);
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
                    // [C124] Stealth mod: useless zombies left alone.
                    || zed.isUseless()
                    // [C9] Choreograph only the fungible crowd: a living
                    // neighbour is a person (DR-009), and a risen known
                    // body's brain is vanilla's, not ours to point
                    // (DR-016 - one brain per body).
                    || com.sao.engine.SAOKnox.identityBearing(zed)
                    // [C124] Non-duplication of aggro: zombie-motivation mods own
                    // their domain; the county does not steal existing targets.
                    || (zed.getTarget() != null && zed.getTarget() != shell)) {
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

    /**
     * [C73] How many forenames the engine ships for this sex.
     *
     * The pools are the game's own (SurvivorFactory.MaleForenames,
     * FemaleForenames, Surnames - public static, no body needed). They are
     * exposed as a length and an index rather than drawn here, because
     * [C66] made every draw in this mod SAO's own: the engine's generator
     * carries no state SAO can see, set or write down, and a county that
     * drew a name from it could not be run twice. The engine owns the
     * names; SAO.Rand owns the draw.
     */
    public int forenameCount(boolean female) {
        try {
            var pool = female ? SurvivorFactory.FemaleForenames
                : SurvivorFactory.MaleForenames;
            return pool == null ? 0 : pool.size();
        } catch (Throwable throwable) {
            SAOAgent.log("forenameCount threw: " + throwable);
            return 0;
        }
    }

    /** [C73] One forename out of the engine's pool, by index. */
    public String forenameAt(boolean female, int index) {
        try {
            var pool = female ? SurvivorFactory.FemaleForenames
                : SurvivorFactory.MaleForenames;
            if (pool == null || index < 0 || index >= pool.size()) {
                return "";
            }
            String name = pool.get(index);
            return name == null ? "" : name;
        } catch (Throwable throwable) {
            SAOAgent.log("forenameAt threw: " + throwable);
            return "";
        }
    }

    /** [C73] How many surnames the engine ships. */
    public int surnameCount() {
        try {
            var pool = SurvivorFactory.Surnames;
            return pool == null ? 0 : pool.size();
        } catch (Throwable throwable) {
            SAOAgent.log("surnameCount threw: " + throwable);
            return 0;
        }
    }

    /** [C73] One surname out of the engine's pool, by index. */
    public String surnameAt(int index) {
        try {
            var pool = SurvivorFactory.Surnames;
            if (pool == null || index < 0 || index >= pool.size()) {
                return "";
            }
            String name = pool.get(index);
            return name == null ? "" : name;
        } catch (Throwable throwable) {
            SAOAgent.log("surnameAt threw: " + throwable);
            return "";
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

    /** [C123] A compact read of the nearby designated ranch, or empty. */
    public String animalCareNear(Object object, double radius) {
        try {
            if (object instanceof SAOIsoPlayerShell shell) {
                return com.sao.engine.SAOAnimals.near(shell, (int) radius);
            }
        } catch (Throwable ignored) {
        }
        return "";
    }

    /** Bind native feeding to one body, animal and actual carried feed. */
    public String animalCareBeginFeed(Object body, Object animal, Object food) {
        return com.sao.engine.SAOAnimalCare.beginFeed(body, animal, food);
    }

    public boolean animalCarePrepareFeed(Object body, String token, Object animal, Object food) {
        return com.sao.engine.SAOAnimalCare.prepareFeed(body, token, animal, food);
    }

    public String animalCareFinishFeed(Object body, String token, Object animal, Object food, boolean completed) {
        return com.sao.engine.SAOAnimalCare.finishFeed(body, token, animal, food, completed);
    }

    public void animalCareCancelFeed(Object body, String token) {
        com.sao.engine.SAOAnimalCare.cancelFeed(body, token);
    }

    /** [C123] The selected ranch animal for a vanilla timed action. */
    public Object animalCareTarget(Object object, int animalId, double radius) {
        try {
            if (object instanceof SAOIsoPlayerShell shell) {
                return com.sao.engine.SAOAnimals.target(shell, animalId,
                    (int) radius);
            }
        } catch (Throwable ignored) {
        }
        return null;
    }

    /** [C123] A nearby trough from the selected animal's own ranch. */
    public Object animalCareTrough(Object object, int animalId, double radius) {
        try {
            if (object instanceof SAOIsoPlayerShell shell) {
                return com.sao.engine.SAOAnimals.trough(shell, animalId,
                    (int) radius);
            }
        } catch (Throwable ignored) {
        }
        return null;
    }

    /** [C123] A hutch nest box holding an actual egg, never a made one. */
    public Object animalCareNestBox(Object object, int animalId, double radius) {
        try {
            if (object instanceof SAOIsoPlayerShell shell) {
                return com.sao.engine.SAOAnimals.nestBoxWithEgg(shell, animalId,
                    (int) radius);
            }
        } catch (Throwable ignored) {
        }
        return null;
    }

    /** [C123] The hutch that owns the returned egg nest box. */
    public Object animalCareHutch(Object object, int animalId, double radius) {
        try {
            if (object instanceof SAOIsoPlayerShell shell) {
                return com.sao.engine.SAOAnimals.hutchWithEgg(shell, animalId,
                    (int) radius);
            }
        } catch (Throwable ignored) {
        }
        return null;
    }

    /** [C123] An engine-listed carried food candidate for the animal. */
    public Object animalCareFeed(Object object, int animalId, double radius) {
        try {
            if (object instanceof SAOIsoPlayerShell shell) {
                return com.sao.engine.SAOAnimals.handFeed(shell, animalId,
                    (int) radius);
            }
        } catch (Throwable ignored) {
        }
        return null;
    }

    /** [C123] A real carried fluid item, if one exists. */
    public Object animalCareWater(Object object) {
        try {
            return object instanceof SAOIsoPlayerShell shell
                ? com.sao.engine.SAOAnimals.carriedWater(shell) : null;
        } catch (Throwable ignored) {
            return null;
        }
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

    /** [C121] The county family of an item, read through the drug
     *  mod's own tag vocabulary; "" when the item is not a drug the
     *  county models. */
    public String drugFamilyOf(Object item) {
        try {
            return com.sao.engine.SAONeeds.drugFamilyOf(item);
        } catch (Throwable unavailable) {
            SAOAgent.log("drug family read refused: " + unavailable);
            return "";
        }
    }

    /** [C121] The first carried drug of a county family, for the
     *  vanilla eat action; null when there is none or the body is not
     *  ours. */
    public Object findCarriedDrug(Object object, String family) {
        if (object instanceof SAOIsoPlayerShell shell) {
            return com.sao.engine.SAONeeds.carriedDrugFor(shell, family);
        }
        return null;
    }

    /** [C121] Scan for a container holding a drug of the family, in
     *  the same remembered-source slot the drink forage uses - the
     *  arrival take and the reach check read the ones they already
     *  read. "x:y:z:name" or "". */
    public String findDrugSource(Object object, double radius, String family) {
        if (object instanceof SAOIsoPlayerShell shell) {
            return com.sao.engine.SAONeeds.findDrugSourceNear(
                shell, (int) radius, family);
        }
        return "";
    }

    /** Carried native food with infection reduction; no clinical outcome is inferred. */
    public Object findCarriedInfectionFood(Object object) {
        if (object instanceof SAOIsoPlayerShell shell) {
            return com.sao.engine.SAONeeds.carriedInfectionFood(shell);
        }
        return null;
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

    public String findWaterSource(Object object, double radius, double atHours) {
        if (object instanceof SAOIsoPlayerShell shell
                && Double.isFinite(atHours) && atHours >= 0) {
            return com.sao.engine.SAONeeds.findWaterSourceNear(shell, (int) radius, atHours);
        }
        return "";
    }

    public boolean failWaterApproach(Object object, String result, double atHours,
            double x, double y, double z) {
        try {
            return object instanceof SAOIsoPlayerShell shell
                && Double.isFinite(x) && Double.isFinite(y) && Double.isFinite(z)
                && x == Math.rint(x) && y == Math.rint(y) && z == Math.rint(z)
                && Math.abs(x) <= 1_000_000 && Math.abs(y) <= 1_000_000 && z >= -32 && z < 32
                && com.sao.engine.SAONeeds.failWaterApproach(shell, result, atHours, (int) x, (int) y, (int) z);
        } catch (Throwable throwable) {
            SAOAgent.log("failWaterApproach threw: " + throwable);
            return false;
        }
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
        try {
            if (object instanceof SAOIsoPlayerShell shell) {
                return com.sao.engine.SAONeeds.findWeaponUpgradeNear(shell, (int) radius);
            }
        } catch (Throwable error) {
            SAOAgent.log("findWeaponUpgrade refused: " + error);
        }
        return "";
    }

    /** Keep the claimed source coordinates separate from its standing tile. */
    public String resourceApproach(Object object, String kind, double x, double y, double z) {
        try {
            if (object instanceof SAOIsoPlayerShell shell
                    && Double.isFinite(x) && Double.isFinite(y) && Double.isFinite(z)
                    && x == Math.rint(x) && y == Math.rint(y) && z == Math.rint(z)
                    && Math.abs(x) <= 1_000_000 && Math.abs(y) <= 1_000_000 && z >= -32 && z < 32) {
                return com.sao.engine.SAONeeds.resourceApproach(shell, kind, (int) x, (int) y, (int) z);
            }
        } catch (Throwable error) { SAOAgent.log("resource approach refused: " + error); }
        return "UNAVAILABLE";
    }

    public Object weaponSourceItem(Object object) {
        try {
            if (object instanceof SAOIsoPlayerShell shell) {
                return com.sao.engine.SAONeeds.weaponSourceItem(shell);
            }
        } catch (Throwable error) { SAOAgent.log("weaponSourceItem refused: " + error); }
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

    /** Current physical and permission check used by world transfer actions. */
    public boolean containerAccessibleNow(Object object, Object containerObject) {
        return object instanceof com.sao.engine.SAOIsoPlayerShell shell
            && containerObject instanceof zombie.inventory.ItemContainer container
            && com.sao.engine.SAONeeds.containerAccessibleNow(shell, container);
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
            var items = com.sao.engine.SAOPrivateInventory.carriedItems(shell);
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
        try {
            if (object instanceof SAOIsoPlayerShell shell) {
                return com.sao.engine.SAONeeds.ammoSourceItem(shell);
            }
        } catch (Throwable error) { SAOAgent.log("ammoSourceItem refused: " + error); }
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
    public Object hibernate(Object object) {
        if (object instanceof SAOIsoPlayerShell shell) {
            try { return SAODurableText.pack(com.sao.engine.SAOHibernation.hibernate(shell)); }
            catch (Throwable error) { SAOAgent.log("hibernate capture refused: " + error); }
        }
        return "";
    }

    public boolean validateHibernation(Object packed) {
        try { return com.sao.engine.SAOHibernation.validate(SAODurableText.unpack(packed)); }
        catch (Throwable error) { return false; }
    }

    public int hibernationVersion(Object packed) {
        try {
            String value = SAODurableText.unpack(packed);
            if (com.sao.engine.SAONativeSnapshot.isNative(value)) {
                return com.sao.engine.SAONativeSnapshot.formatVersion(value);
            }
            if (value != null && value.startsWith("v2;")) return 2;
            if (value != null && value.startsWith("v1;")) return 1;
        } catch (Throwable error) { }
        return 0;
    }

    /** [C71] Fresh recursive carriage for loaded decision code. */
    public Object privateCarriedItems(Object object) {
        try {
            if (object instanceof zombie.characters.IsoGameCharacter person) {
                return com.sao.engine.SAOPrivateInventory.carriedItems(person);
            }
        } catch (Throwable error) { SAOAgent.log("privateCarriedItems refused: " + error); }
        return new java.util.ArrayList<>();
    }

    /** Exact material item counts from this ordinary body's recursive inventory. */
    public int constructionMaterialCount(Object object, String category) {
        if (!(object instanceof zombie.characters.IsoPlayer person)
                || category == null || !(category.equals("glass-pane")
                    || category.equals("hammer") || category.equals("plank")
                    || category.equals("pipe-wrench")
                    || category.equals("garbage-bag") || category.equals("tarp") || category.equals("mattress") || category.equals("hinge") || category.equals("doorknob")
                    || category.equals("electronics-scrap") || category.equals("petrol") || category.equals("generator-manual")
                    || category.equals("nails") || category.equals("log")
                    || category.equals("saw") || category.equals("file")
                    || category.equals("whetstone"))) return 0;
        try {
            int count = 0;
            for (zombie.inventory.InventoryItem item
                    : com.sao.engine.SAOPrivateInventory.carriedItems(person)) {
                if (com.sao.engine.SAONeeds.wantsMaterial(item, category)
                        && !item.getIsCraftingConsumed()
                        && (!category.equals("nails")
                            || "Base.Nails".equals(item.getFullType()))) count++;
            }
            return count;
        } catch (Throwable error) {
            SAOAgent.log("constructionMaterialCount refused: " + error);
            return 0;
        }
    }

    /** [C71] Exact holder rows; this is a read and owns no inventory state. */
    public String privateInventoryLoaded(Object object, double radius) {
        try {
            if (object instanceof zombie.characters.IsoPlayer person) {
                return com.sao.engine.SAOPrivateInventory.encodeLoaded(person,
                    (int) radius);
            }
        } catch (Throwable error) {
            SAOAgent.log("privateInventoryLoaded refused: " + error);
        }
        return "H|protocol=SAOPI1|representation=loaded|carried=unknown|"
            + "world=unknown:missing-body|aggregate=refused|revision=\nE\n";
    }

    /** [C71] Exact v4 carried rows; dormant world access remains unknown. */
    public String privateInventoryDormant(String personId, Object packed) {
        try {
            return com.sao.engine.SAOPrivateInventory.encodeDormant(personId,
                SAODurableText.unpack(packed));
        } catch (Throwable error) {
            return "H|protocol=SAOPI1|representation=dormant|carried=unknown|"
                + "world=unknown:invalid-snapshot|aggregate=refused|revision=\nE\n";
        }
    }

    /** [C71] Exact native radio possession; unsupported snapshots refuse. */
    public boolean privateDormantHasRadio(Object packed) {
        try {
            return com.sao.engine.SAOPrivateInventory.dormantHasRadio(
                SAODurableText.unpack(packed));
        } catch (Throwable unavailable) {
            return false;
        }
    }

    /** [C71] Recursive items for a selected native holder. */
    public Object privateContainerItems(Object object) {
        try {
            if (object instanceof zombie.inventory.ItemContainer container) {
                return com.sao.engine.SAOPrivateInventory.containerItems(container);
            }
        } catch (Throwable error) { SAOAgent.log("privateContainerItems refused: " + error); }
        return new java.util.ArrayList<>();
    }

    /** [C71] Recursive current corpse inventory inside the actor's view. */
    public Object privateCorpseItems(Object object, double radius) {
        try {
            if (object instanceof zombie.characters.IsoPlayer person) {
                return com.sao.engine.SAOPrivateInventory.nearbyCorpseItems(person,
                    (int) radius);
            }
        } catch (Throwable error) { SAOAgent.log("privateCorpseItems refused: " + error); }
        return new java.util.ArrayList<>();
    }

    public boolean privateItemIsRadio(Object object) {
        try {
            return object instanceof zombie.inventory.InventoryItem item
                && com.sao.engine.SAOPrivateInventory.isRadioReceiver(item);
        } catch (Throwable error) {
            SAOAgent.log("privateItemIsRadio refused: " + error);
            return false;
        }
    }

    /** Exact direct-root receiver state staged with the body checkpoint. */
    public String captureRadioState(Object object) {
        try {
            return object instanceof zombie.characters.IsoGameCharacter person
                ? com.sao.engine.SAOPrivateInventory.captureRadioState(person) : "";
        } catch (Throwable error) {
            SAOAgent.log("captureRadioState refused: " + error);
            return "";
        }
    }

    public boolean validateRadioState(Object value) {
        return value instanceof String text
            && com.sao.engine.SAOPrivateInventory.validateRadioState(text);
    }

    public String advanceDormantRadioState(Object value, double elapsedHours) {
        return value instanceof String text
            ? com.sao.engine.SAOPrivateInventory.advanceRadioState(
                text, elapsedHours) : "";
    }

    public String loadedRadioReceiverAccess(Object object, int frequency) {
        return object instanceof zombie.characters.IsoGameCharacter person
            ? com.sao.engine.SAOPrivateInventory.loadedRadioAccess(
                person, frequency, false) : "REFUSED:missing-body";
    }

    public String loadedRadioTransmitterAccess(Object object, int frequency) {
        return object instanceof zombie.characters.IsoGameCharacter person
            ? com.sao.engine.SAOPrivateInventory.loadedRadioAccess(
                person, frequency, true) : "REFUSED:missing-body";
    }

    public String dormantRadioReceiverAccess(Object value, int frequency) {
        return value instanceof String text
            ? com.sao.engine.SAOPrivateInventory.dormantRadioAccess(
                text, frequency, false) : "REFUSED:state-unavailable";
    }

    public boolean applyDormantRadioState(Object object, Object value) {
        return object instanceof zombie.characters.IsoGameCharacter person
            && value instanceof String text
            && com.sao.engine.SAOPrivateInventory.applyRadioState(person, text);
    }

    public boolean canReceiveRadioNow(Object object) {
        return object instanceof zombie.characters.IsoGameCharacter person
            && com.sao.engine.SAOPerceptionScanner.canReceiveRadioNow(person);
    }

    public boolean canTransmitRadioNow(Object object) {
        return object instanceof zombie.characters.IsoGameCharacter person
            && com.sao.engine.SAOPerceptionScanner.canTransmitRadioNow(person);
    }

    /** [C67] Native saved hearing; unavailable evidence never means can-hear. */
    public String hibernationHearingAccess(Object packed) {
        try {
            return com.sao.engine.SAONativeSnapshot.hearingAccess(SAODurableText.unpack(packed));
        } catch (Throwable unavailable) {
            return "UNKNOWN:invalid-snapshot";
        }
    }

    /** Native fatigue/endurance and saved sleep traits, without a body. */
    public String hibernationRestState(Object packed) {
        try {
            return com.sao.engine.SAONativeSnapshot.restState(SAODurableText.unpack(packed));
        } catch (Throwable unavailable) {
            return "UNKNOWN:invalid-snapshot";
        }
    }

    /** Engine-normalized awake fatigue gain per county/game hour. */
    public double dormantAwakeFatiguePerHour() {
        return com.sao.engine.SAONativeSnapshot.awakeFatiguePerHour();
    }

    /** Put the completed bodyless physiology interval onto a restored shell. */
    public boolean applyDormantRestState(Object object, double fatigue, double endurance) {
        return object instanceof zombie.characters.IsoPlayer person
            && com.sao.engine.SAONativeSnapshot.applyRestState(person, fatigue, endurance);
    }

    public Object createReturnBody(String first, String last, double x, double y, double z, boolean female) {
        return com.sao.engine.SAOReturnBody.create(first, last, x, y, z, female);
    }

    public boolean publishReturnBody(Object object) {
        return object instanceof SAOIsoPlayerShell shell && com.sao.engine.SAOReturnBody.publish(shell);
    }

    public Object findReturnDestination(String personId, String token) {
        try {
            return com.sao.engine.SAOReturnBody.find(personId, token);
        } catch (Throwable error) {
            SAOAgent.log("findReturnDestination refused: " + error);
            // Lookup failure must not masquerade as absence and create another body.
            throw new IllegalStateException("Return destination lookup failed", error);
        }
    }

    public boolean returnBodyNeedsCleanup(Object object) {
        return !(object instanceof SAOIsoPlayerShell shell)
            || com.sao.engine.SAOReturnBody.needsCleanup(shell);
    }

    public boolean activateReturnBody(Object object) {
        return object instanceof SAOIsoPlayerShell shell && com.sao.engine.SAOReturnBody.activate(shell);
    }

    public boolean discardReturnBody(Object object) {
        return object instanceof SAOIsoPlayerShell shell && com.sao.engine.SAOReturnBody.discard(shell);
    }

    public boolean restoreReturnLiving(Object object, Object value) {
        if (!(object instanceof SAOIsoPlayerShell shell)) return false;
        try {
            String packed = SAODurableText.unpack(value);
            if (com.sao.engine.SAONativeSnapshot.isNative(packed)) {
                com.sao.engine.SAONativeSnapshot.restoreStaged(shell, packed);
                return true;
            }
            // Original legacy fidelity is retained; no elapsed metabolism is
            // charged while a returned person is held between representations.
            String result = com.sao.engine.SAOHibernation.awaken(shell, packed, 0);
            com.sao.engine.SAONativeSnapshot.unregister(shell);
            return result.startsWith("AWAKENED ");
        } catch (Throwable error) {
            SAOAgent.log("return living state refused: " + error);
            return false;
        }
    }

    public Object captureReturn(Object source, Object destination) {
        if (!(source instanceof zombie.characters.IsoZombie zombie)
                || !(destination instanceof SAOIsoPlayerShell shell)) return "";
        try { return SAODurableText.pack(com.sao.engine.SAONativeSnapshot.captureReturn(zombie, shell)); }
        catch (Throwable error) { SAOAgent.log("return capture refused: " + error); return ""; }
    }

    public Object captureWeekOne(Object source, Object destination, Object brain) {
        if (!(source instanceof zombie.characters.IsoZombie zombie)
                || !(destination instanceof SAOIsoPlayerShell shell)
                || !(brain instanceof se.krka.kahlua.vm.KahluaTable sourceBrain)) return "";
        try { return SAODurableText.pack(com.sao.engine.SAONativeSnapshot.captureWeekOne(
            zombie, shell, sourceBrain)); }
        catch (Throwable error) { SAOAgent.log("Week One capture refused: " + error); return ""; }
    }

    public Object captureReturnLiving(Object object) {
        if (!(object instanceof SAOIsoPlayerShell shell)) return "";
        try { return SAODurableText.pack(com.sao.engine.SAONativeSnapshot.captureReturnLiving(shell)); }
        catch (Throwable error) { SAOAgent.log("living return capture refused: " + error); return ""; }
    }

    public Object captureReturnVisual(Object source) {
        if (!(source instanceof IsoGameCharacter character)) return "";
        try { return SAODurableText.pack(com.sao.engine.SAONativeSnapshot.captureReturnVisual(character)); }
        catch (Throwable error) { SAOAgent.log("return visual refused: " + error); return ""; }
    }

    public boolean validateReturnVisual(Object packed) {
        try { return com.sao.engine.SAONativeSnapshot.validateReturnVisual(SAODurableText.unpack(packed)); }
        catch (Throwable error) { return false; }
    }

    public boolean restoreReturnVisual(Object destination, Object packed) {
        if (!(destination instanceof SAOIsoPlayerShell shell)) return false;
        try { com.sao.engine.SAONativeSnapshot.restoreReturnVisual(shell, SAODurableText.unpack(packed)); return true; }
        catch (Throwable error) { SAOAgent.log("return visual restore refused: " + error); return false; }
    }

    public boolean returnMaterialsMatch(Object source, Object packed, Object visual) {
        if (!(source instanceof zombie.characters.IsoZombie zombie)) return false;
        try { return com.sao.engine.SAONativeSnapshot.returnMaterialsMatch(zombie, SAODurableText.unpack(packed))
            && com.sao.engine.SAONativeSnapshot.captureReturnVisual(zombie).equals(SAODurableText.unpack(visual)); }
        catch (Throwable error) { return false; }
    }

    /** A vehicle occupant or running engine action still owns world state. */
    public boolean canReleaseShell(Object object) {
        try {
            return object instanceof SAOIsoPlayerShell shell
                && shell.getVehicle() == null && shell.getCharacterActions().isEmpty();
        } catch (Throwable throwable) {
            return false;
        }
    }

    /** Incoming transfers can own an item or a container inside a carried bag. */
    public boolean isInventoryOf(Object object, Object reference) {
        try {
            if (!(object instanceof IsoGameCharacter character)) return false;
            zombie.inventory.ItemContainer container = null;
            if (reference instanceof zombie.inventory.ItemContainer value) container = value;
            if (reference instanceof zombie.inventory.InventoryItem item) container = item.getContainer();
            return container != null
                && container.getOutermostContainer() == character.getInventory();
        } catch (Throwable throwable) {
            // An unreadable incoming inventory reference retains ownership.
            return true;
        }
    }

    /** Restore a snapshot onto a fresh body and run dormant metabolism. */
    public String awaken(Object object, Object packed, double elapsedHours) {
        if (object instanceof SAOIsoPlayerShell shell) {
            try { return com.sao.engine.SAOHibernation.awaken(shell, SAODurableText.unpack(packed), elapsedHours); }
            catch (Throwable error) { SAOAgent.log("awaken refused: " + error); return "AWAKEN_FAILED " + error; }
        }
        return "NOT_A_SHELL";
    }

    /** Continue the existing physiological owner between pharmacology slices. */
    public String advanceDormantMetabolism(Object object, double elapsedHours) {
        try { return object instanceof SAOIsoPlayerShell body
            ? com.sao.engine.SAOHibernation.advanceDormantMetabolism(body, elapsedHours)
            : "METABOLISM_FAILED not a shell";
        } catch (Throwable error) { SAOAgent.log("dormant metabolism refused: " + error); return "METABOLISM_FAILED " + error; }
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

    public se.krka.kahlua.vm.KahluaTable recoveryPlaces(Object object, int radius) {
        try {
            var result=object instanceof SAOIsoPlayerShell body
                ? com.sao.engine.SAORecoveryPlace.observe(body,radius) : null;
            if(result==null)result=recoveryPlaceUnavailable("unavailable","native-body-or-range-unavailable");
            if(object instanceof SAOIsoPlayerShell body){
                var report=(se.krka.kahlua.vm.KahluaTable)result.rawget("diagnostics");
                report.rawset("nativeAsleep",body.isAsleep());report.rawset("nativeOnBed",body.isOnBed());
            }
            return result;
        } catch (Throwable error) {
            SAOAgent.log("recovery places unavailable: " + error);
            return recoveryPlaceUnavailable("error","native-query-error");
        }
    }

    private static se.krka.kahlua.vm.KahluaTable recoveryPlaceUnavailable(String status,String reason) {
        var result=zombie.Lua.LuaManager.platform.newTable();var report=zombie.Lua.LuaManager.platform.newTable();
        result.rawset("status",status);result.rawset("diagnostics",report);
        report.rawset("schema","sao.recovery-place-diagnostics/1");report.rawset("bodyAdmission","unavailable");
        report.rawset("reason",reason);return result;
    }

    public boolean recoveryGroundClear(Object object, double x, double y, double z) {
        try { return object instanceof SAOIsoPlayerShell body
            && com.sao.engine.SAORecoveryPlace.groundClear(body,x,y,z);
        } catch (Throwable error) { return false; }
    }

    public zombie.iso.IsoObject recoveryBed(Object object, String key) {
        try { return object instanceof SAOIsoPlayerShell body
            ? com.sao.engine.SAORecoveryPlace.resolveBed(body,key) : null;
        } catch (Throwable error) { return null; }
    }

    /** Actual active recovery pose on this body; inspection never requests a pose. */
    public boolean isRecoveryPose(Object object, String kind) {
        try {
            return object instanceof SAOIsoPlayerShell shell
                && com.sao.engine.SAORecoveryPose.isRecoveryPose(shell, kind);
        } catch (Throwable error) {
            SAOAgent.log("recovery pose unavailable: " + error);
            return false;
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

    /** [C114] Driving verbs, the movement idiom: nothing in the hot
     *  path is Lua-reachable, verdicts are one-line strings. */
    private SAODriveState driveState(SAOIsoPlayerShell shell) {
        return drives.computeIfAbsent(shell, ignored -> new SAODriveState());
    }

    /** [C114] A goer's drive: walk to the claimed car, start it
     *  lawfully, drive to (tx,ty), stop. One-line verdict. [C115] The
     *  speed cap crosses here - the sandbox dial, read by the Lua
     *  face, because Java cannot read SandboxVars.
     *
     *  [C116] The map's second entry: a crossed body - an IsoZombie
     *  the sister's controller owns - is the named consumer of this
     *  verb ([A13], [A32] named the widening ours), and the two
     *  entry types are dispatched, never conflated: the survivor's
     *  trip runs SAODriver unchanged, the crossed body runs the
     *  engine's own zombie pathing through SAOCrossedDriver, and
     *  anything else is still NOT_A_SHELL. */
    public String driveBegin(Object object, int radius, String name,
            double tx, double ty, double speedCapKmh) {
        try {
            if (object instanceof zombie.characters.IsoZombie zombie) {
                SAODriveState state = crossedDrives.computeIfAbsent(
                    zombie, ignored -> new SAODriveState());
                return com.sao.engine.SAOCrossedDriver.begin(
                    zombie, state, radius, name,
                    (int) tx, (int) ty, (float) speedCapKmh);
            }
            if (!(object instanceof SAOIsoPlayerShell shell)) {
                return "NOT_A_SHELL";
            }
            return SAODriver.begin(shell, routeState(shell),
                driveState(shell), radius, name,
                (int) tx, (int) ty, (float) speedCapKmh);
        } catch (Throwable throwable) {
            SAOAgent.log("driveBegin threw: " + throwable);
            return "DRIVE_FAILED " + throwable;
        }
    }

    /** [C114] Company boards the car ([B19]'s seat cap made real). */
    public String rideBegin(Object object, int radius, String name) {
        try {
            if (!(object instanceof SAOIsoPlayerShell shell)) {
                return "NOT_A_SHELL";
            }
            return SAODriver.beginRide(shell, routeState(shell),
                driveState(shell), radius, name);
        } catch (Throwable throwable) {
            SAOAgent.log("rideBegin threw: " + throwable);
            return "RIDE_FAILED " + throwable;
        }
    }

    /** [C114] The driver holds for this many seated passengers before
     * departing; called after the join decision names the party. */
    public boolean driveWaitSeats(Object object, int seats) {
        try {
            if (!(object instanceof SAOIsoPlayerShell shell)) {
                return false;
            }
            SAODriveState state = drives.get(shell);
            if (state == null) return false;
            SAODriver.waitSeats(shell, state, seats);
            return true;
        } catch (Throwable throwable) {
            SAOAgent.log("driveWaitSeats threw: " + throwable);
            return false;
        }
    }

    public String tickDrive(Object object) {
        try {
            if (object instanceof zombie.characters.IsoZombie zombie) {
                SAODriveState state = crossedDrives.get(zombie);
                if (state == null || !state.requested) {
                    return "IDLE";
                }
                // A thrown tick ends the crossed trip under a verdict
                // the sister's machine already reads as terminal: a
                // body that cannot be ticked is not a body that is
                // still driving, and a foreign verdict would hold its
                // movement committed forever.
                try {
                    return com.sao.engine.SAOCrossedDriver.tick(
                        zombie, state);
                } catch (Throwable crossedTick) {
                    SAOAgent.log("crossed tickDrive threw: " + crossedTick);
                    state.requested = false;
                    return "DRIVE_FAILED " + crossedTick;
                }
            }
            if (!(object instanceof SAOIsoPlayerShell shell)) {
                return "NOT_A_SHELL";
            }
            SAODriveState state = drives.get(shell);
            if (state == null || !state.requested) {
                return "IDLE";
            }
            return SAODriver.tick(shell, routeState(shell), state);
        } catch (Throwable throwable) {
            SAOAgent.log("tickDrive threw: " + throwable);
            return "TICK_FAILED " + throwable;
        }
    }

    public String cancelDrive(Object object) {
        try {
            if (!(object instanceof SAOIsoPlayerShell shell)) {
                return "NOT_A_SHELL";
            }
            SAODriveState state = drives.get(shell);
            if (state == null) {
                return "DRIVE_CANCELLED";
            }
            return SAODriver.cancel(shell, routeState(shell), state);
        } catch (Throwable throwable) {
            SAOAgent.log("cancelDrive threw: " + throwable);
            return "CANCEL_FAILED " + throwable;
        }
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

    public String perceive(Object object, String knownTiles) {
        try {
            // [B41] Any character with a body. The real player
            // reached this and got "" back, which is why their
            // belief store only ever held what they were TOLD.
            if (!(object instanceof zombie.characters.IsoGameCharacter who)) {
                return "";
            }
            return com.sao.engine.SAOPerceptionScanner.scan(who, knownTiles);
        } catch (Throwable throwable) {
            SAOAgent.log("perceive threw: " + throwable);
            return "";
        }
    }

    /** Native audible rows only, acquired on the person's observation call. */
    public String perceiveAudibleSounds(Object object) {
        try {
            if (!(object instanceof zombie.characters.IsoGameCharacter who)) return "";
            return com.sao.engine.SAOPerceptionScanner.scanAudibleSounds(who);
        } catch (Throwable throwable) {
            SAOAgent.log("perceiveAudibleSounds threw: " + throwable);
            return "";
        }
    }

    /** Exact native emission, called by Gesture's currently owned instrument action. */
    public se.krka.kahlua.vm.KahluaTable bindInstrumentOccurrence(Object body, Object sound, String workId) {
        try { return com.sao.engine.SAOWorldSoundPulses.bindInstrument(body, sound, workId); }
        catch (Throwable error) { return null; }
    }

    /** BanditsWeekOne keeps the performance actuator; this binds its exact audible occurrence. */
    public se.krka.kahlua.vm.KahluaTable bindWeekOnePerformanceOccurrence(Object body,
            Object sound, String actorId, double brainId, double born,
            String soundId, double soundHandle) {
        try { return com.sao.engine.SAOWorldSoundPulses.bindWeekOnePerformance(
            body, sound, actorId, brainId, born, soundId, soundHandle); }
        catch (Throwable error) { return null; }
    }

    public boolean renewWeekOnePerformanceOccurrence(Object body, String pulseId) {
        try { return com.sao.engine.SAOWorldSoundPulses.renewWeekOnePerformance(body, pulseId); }
        catch (Throwable error) { return false; }
    }

    public boolean revokeWeekOnePerformanceOccurrence(Object body, String pulseId) {
        try { return com.sao.engine.SAOWorldSoundPulses.revokeWeekOnePerformance(body, pulseId); }
        catch (Throwable error) { return false; }
    }

    /** Week One reads an exact, freshly visible private sight referent. */
    public String weekOneObservedTarget(Object object, String kind, String key) {
        try {
            return object instanceof zombie.characters.IsoZombie zombie
                ? com.sao.engine.SAOPerceptionScanner.weekOneObservedTarget(zombie, kind, key)
                : "REFUSED\tbody";
        } catch (Throwable error) {
            SAOAgent.log("weekOneObservedTarget threw: " + error);
            return "REFUSED\tnative";
        }
    }

    /**
     * A hit callback supplies a native attacker object. Match that same
     * object against this person's own last scan and current line of sight;
     * two actors standing on one tile may never borrow one another's belief.
     */
    public boolean weekOneObservedAttacker(Object observerObject,
            Object attackerObject, String kind, String key) {
        try {
            return observerObject instanceof zombie.characters.IsoZombie observer
                && attackerObject instanceof IsoGameCharacter attacker
                && ("person".equals(kind) || "zombie".equals(kind))
                && com.sao.engine.SAOPerceptionScanner.observedCombatTarget(
                    observer, kind, key) == attacker;
        } catch (Throwable error) {
            SAOAgent.log("weekOneObservedAttacker refused: " + error);
            return false;
        }
    }

    /** Current native hearing for one exact stamped Week One proxy listening
     * to the actual player. Lua retains person judgment and speech delivery. */
    public boolean weekOneCanHearPlayer(Object playerObject, Object bodyObject,
            String personId, Object brainId, Object born) {
        try {
            return playerObject instanceof zombie.characters.IsoPlayer player
                && bodyObject instanceof zombie.characters.IsoZombie body
                && com.sao.engine.SAOPerceptionScanner.weekOneCanHearPlayer(
                    player, body, personId, brainId, born);
        } catch (Throwable error) {
            SAOAgent.log("weekOneCanHearPlayer refused: " + error);
            return false;
        }
    }

    /** Read the native action state after the game's shout/horn handler ran.
     * Source chat's quiet tokens and key codes are not occurrence evidence. */
    public boolean weekOneNativeSignalActive(Object playerObject, String kind) {
        try {
            if (!(playerObject instanceof IsoPlayer player)
                    || player.isDead() || player.isAsleep()) return false;
            boolean current = false;
            for (IsoPlayer slot : IsoPlayer.players) {
                if (slot == player) { current = true; break; }
            }
            if (!current) return false;
            if ("callout".equals(kind)) return player.callOut;
            if (!"horn".equals(kind)) return false;
            var vehicle = player.getVehicle();
            return vehicle != null && vehicle.isDriver(player)
                && vehicle.getScript() != null
                && vehicle.getScript().getSounds() != null
                && vehicle.getScript().getSounds().hornEnable
                && vehicle.isHornSounding();
        } catch (Throwable error) {
            return false;
        }
    }

    /** Pulse emitted by the installed Callout() invocation. A held callOut
     * boolean or a same-source sound emitted elsewhere has no identifier. */
    public String weekOneNativeCalloutOccurrence(Object playerObject) {
        try {
            return playerObject instanceof IsoPlayer player
                && weekOneNativeSignalActive(player, "callout")
                ? com.sao.engine.SAOWorldSoundPulses.nativeCalloutId(player) : null;
        } catch (Throwable error) {
            return null;
        }
    }

    /** One current native sound from the actual player or driven vehicle,
     * heard by the exact still-stamped Week One body. This establishes sound
     * contact only; neither a word nor a request is inferred from it. */
    public boolean weekOneNativeSignalHeard(Object playerObject, Object bodyObject,
            String personId, Object brainId, Object born, String kind) {
        try {
            if (!(playerObject instanceof IsoPlayer player)
                    || !(bodyObject instanceof zombie.characters.IsoZombie body)
                    || !weekOneNativeSignalActive(player, kind)
                    || personId == null || !personId.startsWith("bwo-")
                    || !(brainId instanceof Number brainNumber)
                    || !(born instanceof Number bornNumber)
                    || !Double.isFinite(brainNumber.doubleValue())
                    || brainNumber.doubleValue() % 1.0 != 0.0
                    || !Double.isFinite(bornNumber.doubleValue())
                    || body.getPersistentOutfitID() != brainNumber.longValue()
                    || !body.getVariableBoolean("Bandit") || body.isDead()
                    || body.isAsleep() || body.hasTrait(zombie.scripting.objects.CharacterTrait.DEAF)
                    || body.getModData() == null
                    || !"BanditsWeekOne".equals(body.getModData().rawget("SAOWeekOneOrigin"))
                    || !personId.equals(body.getModData().rawget("SAOWeekOnePersonId"))
                    || !(body.getModData().rawget("SAOWeekOneBrainId") instanceof Number markedBrain)
                    || markedBrain.doubleValue() != brainNumber.doubleValue()
                    || !(body.getModData().rawget("SAOWeekOneBorn") instanceof Number markedBorn)
                    || Double.compare(markedBorn.doubleValue(), bornNumber.doubleValue()) != 0
                    || player.getCell() == null || body.getCell() != player.getCell()
                    || player.getCurrentSquare() == null || body.getCurrentSquare() == null
                    || player.getCell().getGridSquare(body.getCurrentSquare().getX(),
                        body.getCurrentSquare().getY(), body.getCurrentSquare().getZ())
                        != body.getCurrentSquare()) return false;
            float distanceModifier = body.getHearDistanceModifier();
            float weather = body.getWeatherHearingMultiplier();
            if (!Float.isFinite(distanceModifier) || distanceModifier <= 0
                    || !Float.isFinite(weather) || weather <= 0) return false;
            float hearing = Math.min(1, 1 / distanceModifier) * Math.min(1, weather);
            if (!Float.isFinite(hearing) || hearing <= 0) return false;
            var manager = zombie.WorldSoundManager.instance;
            if (manager == null || manager.soundList == null) return false;
            var vehicle = "horn".equals(kind) ? player.getVehicle() : null;
            var calloutSound = "callout".equals(kind)
                ? com.sao.engine.SAOWorldSoundPulses.nativeCalloutSound(player) : null;
            if ("callout".equals(kind) && calloutSound == null) return false;
            for (var sound : manager.soundList) {
                if (sound == null || sound.life <= 0) continue;
                if (vehicle != null) {
                    if (sound.source != vehicle || sound.radius != 150) continue;
                } else if ("callout".equals(kind)) {
                    if (sound != calloutSound || sound.source != player || sound.radius != 6
                            && sound.radius != 18 && sound.radius != 30
                            && sound.radius != 90) continue;
                } else return false;
                if (Math.abs(body.getZ() - sound.z) >= .5f) continue;
                double dx = body.getX() - (sound.x + .5);
                double dy = body.getY() - (sound.y + .5);
                double reach = sound.radius * hearing;
                if (dx * dx + dy * dy > reach * reach) continue;
                var origin = player.getCell().getGridSquare(sound.x, sound.y, sound.z);
                if (origin == null) continue;
                var path = zombie.iso.LosUtil.lineClear(player.getCell(),
                    origin.getX(), origin.getY(), origin.getZ(),
                    body.getCurrentSquare().getX(), body.getCurrentSquare().getY(),
                    body.getCurrentSquare().getZ(), false);
                if (path == zombie.iso.LosUtil.TestResults.Clear
                        || path == zombie.iso.LosUtil.TestResults.ClearThroughOpenDoor) return true;
            }
            return false;
        } catch (Throwable error) {
            return false;
        }
    }

    /** Use-time read of an actual local feature for an SAO-owned Week One role. */
    public boolean weekOneObservedFeature(Object observerObject,
            Object candidate, String kind) {
        try {
            return observerObject instanceof zombie.characters.IsoZombie observer
                && com.sao.engine.SAOPerceptionScanner.weekOneObservedFeature(
                    observer, candidate, kind);
        } catch (Throwable error) {
            SAOAgent.log("weekOneObservedFeature threw: " + error);
            return false;
        }
    }

    public String weekOneObservedCareTarget(Object observerObject, String name) {
        try {
            return observerObject instanceof zombie.characters.IsoZombie observer
                ? com.sao.engine.SAOPerceptionScanner.weekOneObservedCareTarget(observer, name)
                : "REFUSED\tbody";
        } catch (Throwable error) {
            SAOAgent.log("weekOneObservedCareTarget threw: " + error);
            return "REFUSED\tnative";
        }
    }

    /** Complete one physically supplied bandage after current native sight. */
    public String weekOneBandageObservedPatient(Object observerObject, String name) {
        try {
            return observerObject instanceof zombie.characters.IsoZombie observer
                ? com.sao.engine.SAOPerceptionScanner.weekOneBandageObservedPatient(
                    observer, name)
                : "REFUSED\tbody";
        } catch (Throwable error) {
            SAOAgent.log("weekOneBandageObservedPatient threw: " + error);
            return "REFUSED\tnative";
        }
    }

    /** Hearing and visible-emitter acquisition; never lists other people's listeners. */
    public se.krka.kahlua.vm.KahluaTable claimInstrumentHearing(Object observer, Object performer,
            String workId, String pulseId) {
        try { return com.sao.engine.SAOWorldSoundPulses.claimInstrument(observer, performer, workId, pulseId); }
        catch (Throwable error) { return null; }
    }

    /** One exact Week One sound enters this observer's private hearing only. */
    public se.krka.kahlua.vm.KahluaTable claimWeekOnePerformanceHearing(Object observer,
            Object performer, String actorId, double brainId, double born, String pulseId) {
        try { return com.sao.engine.SAOWorldSoundPulses.claimWeekOnePerformance(
            observer, performer, actorId, brainId, born, pulseId); }
        catch (Throwable error) { return null; }
    }

    /** Own carried food and native recognition; no hidden world items are consulted. */
    public se.krka.kahlua.vm.KahluaTable personalFoodKnowledge(Object object) {
        try { return object instanceof SAOIsoPlayerShell body
            ? com.sao.engine.SAOConceptObservation.foodKnowledge(body) : null;
        } catch (Throwable error) { return null; }
    }
    public Object personalFoodChoice(Object object, double itemId, String itemType,
            boolean recognizedPoison, String basis) {
        try { return object instanceof SAOIsoPlayerShell body
            ? com.sao.engine.SAOConceptObservation.foodChoice(body, itemId, itemType, recognizedPoison, basis) : null;
        } catch (Throwable error) { return null; }
    }

    /** Actor-visible concept anchors and doorway hypotheses; no native objects leave this read. */
    public se.krka.kahlua.vm.KahluaTable conceptObservations(Object object, int radius) {
        try {
            return object instanceof SAOIsoPlayerShell body
                ? com.sao.engine.SAOConceptObservation.observe(body, radius) : null;
        } catch (Throwable error) { SAOAgent.log("concept observations unavailable: " + error); return null; }
    }

    /** [C60] Recheck a perceived action participant at the point of use. */
    public boolean canSeePersonNow(Object observerObject, Object otherObject,
                                   double actionRange) {
        try {
            if (!(observerObject instanceof zombie.characters.IsoGameCharacter observer)
                    || !(otherObject instanceof zombie.characters.IsoGameCharacter other)) {
                return false;
            }
            return com.sao.engine.SAOPerceptionScanner.canSeePersonNow(
                observer, other, (float) actionRange);
        } catch (Throwable throwable) {
            return false;
        }
    }

    /** [C67] Current actor and exact holder visibility for transfer witnesses. */
    public boolean canWitnessWorldTransfer(Object observerObject, Object actorObject,
            Object containerObject, double range) {
        try {
            if (!(observerObject instanceof IsoGameCharacter observer)
                    || !(actorObject instanceof IsoGameCharacter actor)
                    || !(containerObject instanceof zombie.inventory.ItemContainer container)
                    || !Double.isFinite(range) || range < 0.0 || range > Float.MAX_VALUE) {
                return false;
            }
            return com.sao.engine.SAOPerceptionScanner.canWitnessWorldTransfer(
                observer, actor, container, (float) range);
        } catch (Throwable unavailable) {
            return false;
        }
    }

    /** [C67] Directed short-range speech admission using current native bodies. */
    public boolean canConverseNow(Object speakerObject, Object listenerObject,
            double range) {
        try {
            if (!(speakerObject instanceof IsoGameCharacter speaker)
                    || !(listenerObject instanceof IsoGameCharacter listener)
                    || !Double.isFinite(range) || range < 0.0 || range > Float.MAX_VALUE) {
                return false;
            }
            return com.sao.engine.SAOPerceptionScanner.canConverseNow(
                speaker, listener, (float) range);
        } catch (Throwable unavailable) {
            return false;
        }
    }

    /** [C67] Shared native speech weather factor; NaN means unavailable. */
    public double speechWeatherHearing() {
        try {
            return com.sao.engine.SAOPerceptionScanner.speechWeatherHearing();
        } catch (Throwable unavailable) {
            return Double.NaN;
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

    public boolean requestOrientation(Object object, String cueId, double x, double y,
            double readiness, double steadiness, boolean allowBodyTurn) {
        try {
            return object instanceof IsoGameCharacter body
                && Double.isFinite(x) && Double.isFinite(y)
                && Double.isFinite(readiness) && readiness >= 0 && readiness <= 1
                && Double.isFinite(steadiness) && steadiness >= 0 && steadiness <= 1
                && com.sao.engine.SAOOrientation.request(body, cueId, (float)x, (float)y,
                    (float)readiness, (float)steadiness, allowBodyTurn);
        } catch (Throwable error) { SAOAgent.log("orientation refused: " + error); return false; }
    }
    public void clearOrientation(Object object) {
        try {
            if (object instanceof IsoGameCharacter body) com.sao.engine.SAOOrientation.clear(body);
        } catch (Throwable error) { SAOAgent.log("orientation release refused: " + error); }
    }
    public boolean requestPosture(Object object, String actionId, double x, double y,
            double readiness, double steadiness, double durationSeconds) {
        try {
            return object instanceof IsoGameCharacter body
                && Double.isFinite(x) && Double.isFinite(y)
                && Double.isFinite(readiness) && readiness >= 0 && readiness <= 1
                && Double.isFinite(steadiness) && steadiness >= 0 && steadiness <= 1
                && Double.isFinite(durationSeconds)
                && com.sao.engine.SAOOrientation.requestPosture(body, actionId,
                    (float)x, (float)y, (float)readiness, (float)steadiness,
                    (float)durationSeconds);
        } catch (Throwable error) { SAOAgent.log("posture refused: " + error); return false; }
    }
    public void clearPosture(Object object, String actionId) {
        try {
            if (object instanceof IsoGameCharacter body)
                com.sao.engine.SAOOrientation.clearPosture(body, actionId);
        } catch (Throwable error) { SAOAgent.log("posture release refused: " + error); }
    }
    public se.krka.kahlua.vm.KahluaTable orientationState(Object object) {
        try { return com.sao.engine.SAOOrientation.state(object instanceof IsoGameCharacter body ? body : null); }
        catch (Throwable error) { SAOAgent.log("orientation inspection unavailable: " + error); return null; }
    }

    public se.krka.kahlua.vm.KahluaTable cookingOffers(Object object, int radius) {
        try { return object instanceof SAOIsoPlayerShell body ? com.sao.engine.SAOCooking.offers(body, radius) : null; }
        catch (Throwable error) { SAOAgent.log("cooking offers unavailable: " + error); return null; }
    }
    public se.krka.kahlua.vm.KahluaTable inspectCookingAppliance(Object object, Object appliance, Object container) {
        try {
            return object instanceof SAOIsoPlayerShell body && appliance instanceof zombie.iso.IsoObject stove
                && container instanceof zombie.inventory.ItemContainer items
                ? com.sao.engine.SAOCooking.inspect(body, stove, items) : null;
        } catch (Throwable error) { SAOAgent.log("cooking inspection unavailable: " + error); return null; }
    }
    public se.krka.kahlua.vm.KahluaTable cookingApproach(Object object, Object appliance, Object container) {
        try {
            return object instanceof SAOIsoPlayerShell body && appliance instanceof zombie.iso.IsoObject stove
                && container instanceof zombie.inventory.ItemContainer items
                ? com.sao.engine.SAOCooking.approach(body, stove, items) : null;
        } catch (Throwable error) { SAOAgent.log("cooking approach unavailable: " + error); return null; }
    }
    public boolean beginCookingHeat(Object object, String workId, Object item, Object appliance, Object container) {
        try {
            return object instanceof SAOIsoPlayerShell body && item instanceof zombie.inventory.InventoryItem food
                && appliance instanceof zombie.iso.IsoObject stove && container instanceof zombie.inventory.ItemContainer items
                && com.sao.engine.SAOCooking.beginHeat(body, workId, food, stove, items);
        } catch (Throwable error) { SAOAgent.log("cooking heat refused: " + error); return false; }
    }
    public se.krka.kahlua.vm.KahluaTable cookingHeatState(Object object, String workId) {
        try { return object instanceof SAOIsoPlayerShell body ? com.sao.engine.SAOCooking.heatState(body, workId) : null; }
        catch (Throwable error) { SAOAgent.log("cooking heat unavailable: " + error); return null; }
    }
    public se.krka.kahlua.vm.KahluaTable completeCookingHeat(Object object, String workId) {
        try { return object instanceof SAOIsoPlayerShell body ? com.sao.engine.SAOCooking.completeHeat(body, workId) : null; }
        catch (Throwable error) { SAOAgent.log("cooking result unavailable: " + error); return null; }
    }
    public void clearCookingHeat(Object object, String workId) {
        try { if (object instanceof SAOIsoPlayerShell body) com.sao.engine.SAOCooking.clearHeat(body, workId); }
        catch (Throwable error) { SAOAgent.log("cooking release unavailable: " + error); }
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

    /** Read-only progress of this body's existing native route. */
    public String moveProgress(Object object) {
        try {
            if (!(object instanceof SAOIsoPlayerShell shell)) return "NOT_A_SHELL";
            SAORouteState state = routes.get(shell);
            return state == null ? "MOVE_PROGRESS_UNAVAILABLE" : state.progress();
        } catch (Throwable throwable) {
            SAOAgent.log("moveProgress threw: " + throwable);
            return "MOVE_PROGRESS_UNAVAILABLE";
        }
    }

    /** Read the exact barrier encountered by this body's last native route. */
    public String moveBarrier(Object object) {
        try {
            if (!(object instanceof SAOIsoPlayerShell shell)) return "NOT_A_SHELL";
            SAORouteState state = routes.get(shell);
            return state == null || state.barrierResult == null
                ? "MOVE_BARRIER_UNAVAILABLE" : state.barrierResult;
        } catch (Throwable unavailable) {
            return "MOVE_BARRIER_UNAVAILABLE";
        }
    }

    /** Consume one actual crossed aperture from this exact body's current route. */
    public String consumeMoveCrossing(Object object) {
        try {
            if (!(object instanceof SAOIsoPlayerShell shell)) return "NOT_A_SHELL";
            SAORouteState state = routes.get(shell);
            return state == null ? "MOVE_CROSSING_UNAVAILABLE" : state.consumeCrossing();
        } catch (Throwable unavailable) {
            return "MOVE_CROSSING_UNAVAILABLE";
        }
    }

    public String horseRoutePoint(Object object) {
        try {
            if (!(object instanceof SAOIsoPlayerShell shell)) {
                return "NOT_A_SHELL";
            }
            return SAOMovement.waypoint(shell, routeState(shell));
        } catch (Throwable throwable) {
            SAOAgent.log("horseRoutePoint threw: " + throwable);
            return "ROUTE_FAILED " + throwable;
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

    /** Read-only absence of both owned and independently started native paths. */
    public boolean movementIdle(Object object) {
        try {
            if (!(object instanceof SAOIsoPlayerShell shell)) return false;
            SAORouteState state = routes.get(shell);
            var behavior = shell.getPathFindBehavior2();
            return (state == null || !state.requested && !state.hasRoute())
                && shell.getPath2() == null && behavior != null
                && (behavior.isGoalNone() || behavior.getIsCancelled());
        } catch (Throwable throwable) {
            SAOAgent.log("movementIdle threw: " + throwable);
            return false;
        }
    }

    /** [C118] One batter at the barrier between this survivor and the
     * goal it was walking to. The composition decides (Disposition's
     * wouldForceEntry, Standing's mayEnter already answered when the
     * walk was ordered); this only swings - see SAOMovement.batter for
     * the law and the honest limits. */
    public String batterBarrier(Object object, double towardX, double towardY) {
        try {
            if (!(object instanceof SAOIsoPlayerShell shell)) {
                return "NOT_A_SHELL";
            }
            return SAOMovement.batter(shell, (int) towardX, (int) towardY);
        } catch (Throwable throwable) {
            SAOAgent.log("batterBarrier threw: " + throwable);
            return "BATTER_FAILED";
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
    public int daysBehindAtStart(boolean dayZeroAsked) {
        try {
            return com.sao.engine.SAORecord.daysBehindAtStart(dayZeroAsked);
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

    /** [C62] The calendar month a county hour falls in, 0 to 11; -1
     *  off the clock. */
    public int countyMonth(double hours, boolean dayZeroAsked) {
        try {
            int[] start = com.sao.engine.SAORecord.saveStart();
            if (start == null) {
                return -1;
            }
            int behind = com.sao.engine.SAORecord.daysBehindAtStart(dayZeroAsked);
            return com.sao.engine.SAORecord.countyMonth0(start[0], start[1], start[2],
                hours, behind);
        } catch (Throwable throwable) {
            return -1;
        }
    }

    /** [C74] The exact local calendar instant on the durable county-hour axis. */
    public String countyInstant(double hours, boolean dayZeroAsked) {
        try {
            int[] start = com.sao.engine.SAORecord.saveStart();
            if (start == null) {
                return "";
            }
            int behind = com.sao.engine.SAORecord.daysBehindAtStart(dayZeroAsked);
            if (behind < 0) {
                return "";
            }
            return com.sao.engine.SAORecord.countyInstant(
                start[0], start[1], start[2], hours, behind);
        } catch (Throwable throwable) {
            return "";
        }
    }

    /** [C74] A shipped-record day expressed on the durable county-hour axis. */
    public double recordHour(int recordDay, boolean dayZeroAsked) {
        try {
            int[] start = com.sao.engine.SAORecord.saveStart();
            if (start == null) {
                return Double.NaN;
            }
            int behind = com.sao.engine.SAORecord.daysBehindAtStart(dayZeroAsked);
            if (behind < 0) {
                return Double.NaN;
            }
            boolean shifted = dayZeroAsked
                && com.sao.engine.SAORecord.mayShift(start[0], start[1], start[2]);
            return com.sao.engine.SAORecord.recordHourFor(
                start[0], start[1], start[2], recordDay, behind, shifted);
        } catch (Throwable throwable) {
            return Double.NaN;
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

    /** This body's present native visibility of one boardable object. */
    public boolean canSeeBoardable(Object body, Object target) {
        return body instanceof zombie.characters.IsoGameCharacter person
            && target instanceof zombie.iso.IsoObject object
            && com.sao.engine.SAOBuild.canSeeBoardable(person, object);
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

    /** [R10a] Readiness of the bounded native-ground seam. */
    public String worldSourceStatus() {
        try {
            return com.sao.engine.SAOWorldSources.status();
        } catch (Throwable throwable) {
            SAOAgent.log("worldSourceStatus threw: " + throwable);
            return "protocol=SAOWS1|weave=FAILED|" + throwable;
        }
    }

    /** [R10a] Populate and persist one demanded PZ chunk, then observe it. */
    public String hydrateWorldChunk(int chunkX, int chunkY) {
        try {
            return com.sao.engine.SAOWorldSources.hydrateChunk(chunkX, chunkY);
        } catch (Throwable throwable) {
            SAOAgent.log("hydrateWorldChunk threw: " + throwable);
            return "";
        }
    }

    /** [R10a] Observe one currently loaded chunk without rolling unopened loot. */
    public String observeWorldChunk(int chunkX, int chunkY) {
        try {
            return com.sao.engine.SAOWorldSources.observeLoadedChunk(chunkX, chunkY);
        } catch (Throwable throwable) {
            SAOAgent.log("observeWorldChunk threw: " + throwable);
            return "";
        }
    }

    /** Exact loose items visible to this native body; no container contents. */
    public Object visibleGroundSources(Object object, double radius) {
        try {
            if (!(object instanceof com.sao.engine.SAOIsoPlayerShell shell)
                    || !Double.isFinite(radius) || radius != Math.rint(radius)) return null;
            return com.sao.engine.SAOWorldSources.visibleGroundSources(shell, (int) radius);
        } catch (Throwable throwable) {
            SAOAgent.log("visibleGroundSources threw: " + throwable);
            return null;
        }
    }

    public Object leisureMaterialRequirements(Object object,String itemType) {
        try { return object instanceof SAOIsoPlayerShell body
            ? com.sao.engine.SAOLeisureMaterials.requirements(body,itemType) : null;
        } catch(Throwable unavailable) { return null; }
    }

    public Object resolveObservedObject(Object object, String key, String runtimeInstance) {
        try { return object instanceof SAOIsoPlayerShell body
            ? com.sao.engine.SAOConceptObservation.resolveVisibleObject(body,key,runtimeInstance) : null;
        } catch (Throwable error) { return null; }
    }
    public Object resolveLeisureAudioSource(Object object,String key,String runtimeInstance) {
        try { return object instanceof SAOIsoPlayerShell body
            ? com.sao.engine.SAOLeisureAudioAccess.resolve(body,key,runtimeInstance) : null;
        } catch(Throwable unavailable) { return null; }
    }
    public boolean canHearLeisureObject(Object object,String key,String runtimeInstance,double range) {
        try {
            if (!(object instanceof SAOIsoPlayerShell body)||!Double.isFinite(range)||range<=0) return false;
            var target=com.sao.engine.SAOConceptObservation.resolveVisibleObject(body,key,runtimeInstance);
            return target!=null&&com.sao.engine.SAOPerceptionScanner.canHearSourceNow(body,target.getSquare(),(float)range);
        } catch(Throwable unavailable) { return false; }
    }
    public boolean canHearLeisureSource(Object object,String key,String runtimeInstance,double range) {
        try { return object instanceof SAOIsoPlayerShell body && Double.isFinite(range)
            && com.sao.engine.SAOLeisureAudioAccess.canHear(body,key,runtimeInstance,(float)range);
        } catch(Throwable unavailable) { return false; }
    }
    public boolean registerNativeRadioWork(Object object,String workId,Object source,String sourceKey){
        try { return com.sao.agent.SAORadioPlaybackWeave.ready()&&object instanceof SAOIsoPlayerShell body
            &&com.sao.engine.SAORadioPlayback.register(body,workId,source,sourceKey);
        } catch (Throwable unavailable) {
            SAOAgent.log("registerNativeRadioWork threw: " + unavailable);
            return false;
        }
    }
    public boolean registerNativeDanceCycle(Object object,String workId,Object action,String clip){
        try {return com.sao.agent.SAODanceCycleWeave.ready()&&object instanceof SAOIsoPlayerShell body
            &&com.sao.engine.SAODanceCycle.register(body,workId,action,clip);
        }catch(Throwable unavailable){return false;}
    }
    public boolean nativeDanceCycleCompletionReady(){return com.sao.agent.SAODanceCycleWeave.ready();}
    public Object observeNativeDanceCycle(Object object,String workId){
        try {return object instanceof SAOIsoPlayerShell body
            ?com.sao.engine.SAODanceCycle.observe(body,workId):null;
        }catch(Throwable unavailable){return null;}
    }
    public boolean nativeDanceCycleCurrent(Object object,String workId,double sequence){
        try {return object instanceof SAOIsoPlayerShell body&&Double.isFinite(sequence)
            &&sequence>0&&sequence==Math.rint(sequence)
            &&com.sao.engine.SAODanceCycle.eventCurrent(body,workId,(long)sequence);
        }catch(Throwable unavailable){return false;}
    }
    public boolean unregisterNativeDanceCycle(Object object,String workId){
        try {return object instanceof SAOIsoPlayerShell body
            &&com.sao.engine.SAODanceCycle.unregister(body,workId);
        }catch(Throwable unavailable){return false;}
    }
    public boolean nativeDanceCycleCompletionCurrent(Object object,String workId,double sequence){
        try {return object instanceof SAOIsoPlayerShell body&&Double.isFinite(sequence)
            &&sequence>0&&sequence==Math.rint(sequence)
            &&com.sao.engine.SAODanceCycle.completionCurrent(body,workId,(long)sequence);
        }catch(Throwable unavailable){return false;}
    }
    public boolean sameNativeLuaSourceFunction(Object loaded,Object audited){
        return com.sao.engine.SAOLuaSourceIdentity.same(loaded,audited);
    }
    public boolean nativeLuaSourceFunctionUsesEnvironment(Object loaded,Object expected){
        return com.sao.engine.SAOLuaSourceIdentity.usesEnvironment(loaded,expected);
    }
    public boolean registerNativeRadioWork(Object object,String workId,Object source,String sourceKey,double countyHours){
        try { return Double.isFinite(countyHours)&&com.sao.agent.SAORadioPlaybackWeave.ready()
            &&object instanceof SAOIsoPlayerShell body
            &&com.sao.engine.SAORadioPlayback.register(body,workId,source,sourceKey,countyHours);
        } catch (Throwable unavailable) {
            SAOAgent.log("registerNativeRadioWork threw: " + unavailable);
            return false;
        }
    }
    public Object tickNativeRadioWork(Object object,String workId){
        try {return com.sao.agent.SAORadioPlaybackWeave.ready()&&object instanceof SAOIsoPlayerShell body
            ?com.sao.engine.SAORadioPlayback.tick(body,workId):null;
        }catch(Throwable unavailable){return null;}
    }
    public boolean nativeRadioPlaybackEventCurrent(Object object,String workId,double sequence,Object source){
        try {return object instanceof SAOIsoPlayerShell body&&Double.isFinite(sequence)
            &&sequence>0&&sequence==Math.rint(sequence)
            &&com.sao.engine.SAORadioPlayback.eventCurrent(body,workId,(long)sequence,source);
        }catch(Throwable unavailable){return false;}
    }
    public boolean unregisterNativeRadioWork(Object object,String workId){
        return object instanceof SAOIsoPlayerShell body
            &&com.sao.engine.SAORadioPlayback.unregister(body,workId);
    }
    public Object nativeRadioPlaybackEvents(Object object,String workId,double afterSequence){
        try {return object instanceof SAOIsoPlayerShell body&&Double.isFinite(afterSequence)
            &&afterSequence>=0&&afterSequence==Math.rint(afterSequence)
            ?com.sao.engine.SAORadioPlayback.events(body,workId,(long)afterSequence):null;
        }catch(Throwable unavailable){return null;}
    }
    public String initFitnessExerciseDefinitions(Object object,Object definitions) {
        try { return object instanceof SAOIsoPlayerShell body
            ? com.sao.engine.SAOFitnessDefinitions.initialize(body,definitions) : "unavailable";
        } catch (Throwable error) { return "unavailable"; }
    }
    public Object nativeLeisureActionSource(String name) {
        try { return com.sao.engine.SAOLeisureActionSource.read(name); }
        catch (Throwable error) { return null; }
    }
    public Object nativeTabletopAffordance(Object object,Object item,String kind) {
        try { return object instanceof SAOIsoPlayerShell body && item instanceof zombie.inventory.InventoryItem owned
            ? com.sao.engine.SAOTabletop.affordance(body,owned,kind) : null;
        } catch (Throwable error) { return null; }
    }
    public Object nativeTabletopComplete(Object object,Object item,String kind,String workId) {
        try { return object instanceof SAOIsoPlayerShell body && item instanceof zombie.inventory.InventoryItem owned
            ? com.sao.engine.SAOTabletop.complete(body,owned,kind,workId) : null;
        } catch (Throwable error) { return null; }
    }
    public boolean fitnessDefinitionsInitialized(Object object) {
        try { return object instanceof SAOIsoPlayerShell body
            && com.sao.engine.SAOFitnessDefinitions.initialized(body);
        } catch (Throwable error) { return false; }
    }
    public double fitnessExerciseXpModifier(Object object,String name) {
        try { return object instanceof SAOIsoPlayerShell body
            ? com.sao.engine.SAOFitnessDefinitions.xpModifier(body,name) : Double.NaN;
        } catch (Throwable error) { return Double.NaN; }
    }

    /** Visible holder identities, with contents left private until inspection. */
    public String worldInspectionCandidates(Object object, double radius) {
        try {
            if (!(object instanceof com.sao.engine.SAOIsoPlayerShell shell)
                    || !Double.isFinite(radius) || radius != Math.rint(radius)) {
                return "NO_LIVE_BODY";
            }
            return com.sao.engine.SAOWorldSources.inspectionCandidates(shell, (int) radius);
        } catch (Throwable throwable) {
            SAOAgent.log("worldInspectionCandidates threw: " + throwable);
            return "FAILED";
        }
    }

    /** Body-owned attempt state; native weak ownership controls its lifetime. */
    public Object worldInspectionMemory(Object object) {
        try {
            return object instanceof com.sao.engine.SAOIsoPlayerShell shell
                ? com.sao.engine.SAOWorldSources.inspectionMemory(shell) : null;
        } catch (Throwable throwable) {
            SAOAgent.log("worldInspectionMemory threw: " + throwable);
            return null;
        }
    }

    /** Inspect the exact offered holder with this actor's native body. */
    public String worldInspectContainer(Object object, String sourceId,
            String fingerprint, double x, double y, double z) {
        try {
            if (!(object instanceof com.sao.engine.SAOIsoPlayerShell shell)
                    || !Double.isFinite(x) || !Double.isFinite(y) || !Double.isFinite(z)
                    || x != Math.rint(x) || y != Math.rint(y) || z != Math.rint(z)) {
                return "NO_LIVE_BODY";
            }
            return com.sao.engine.SAOWorldSources.inspectContainer(shell, sourceId,
                fingerprint, (int) x, (int) y, (int) z);
        } catch (Throwable throwable) {
            SAOAgent.log("worldInspectContainer threw: " + throwable);
            return "FAILED";
        }
    }

    /** [C62] Resolve an observed source revision to a native interaction tile. */
    public String worldSourceActionTarget(Object object, String sourceId,
            String fingerprint, String revision, double itemId, String itemType,
            double x, double y, double z) {
        try {
            if (object instanceof com.sao.engine.SAOIsoPlayerShell shell) {
                return com.sao.engine.SAOWorldSources.actionTarget(shell,
                    sourceId, fingerprint, revision, (int) itemId, itemType,
                    (int) x, (int) y, (int) z);
            }
            return "NO_LIVE_BODY";
        } catch (Throwable throwable) {
            SAOAgent.log("worldSourceActionTarget threw: " + throwable);
            return "FAILED";
        }
    }

    public String worldRefillTarget(Object object, String sourceId, String fingerprint,
            String revision, double x, double y, double z) {
        try {
            return object instanceof com.sao.engine.SAOIsoPlayerShell shell
                && Double.isFinite(x) && Double.isFinite(y) && Double.isFinite(z)
                && x == Math.rint(x) && y == Math.rint(y) && z == Math.rint(z)
                ? com.sao.engine.SAOWorldSources.refillTarget(shell, sourceId, fingerprint,
                    revision, (int) x, (int) y, (int) z) : "BAD_REFILL_REQUEST";
        } catch (Throwable throwable) {
            SAOAgent.log("worldRefillTarget threw: " + throwable);
            return "FAILED";
        }
    }

    public Object worldRefillObject(Object object, String sourceId, String fingerprint,
            String revision, double x, double y, double z) {
        try {
            return object instanceof com.sao.engine.SAOIsoPlayerShell shell
                && Double.isFinite(x) && Double.isFinite(y) && Double.isFinite(z)
                && x == Math.rint(x) && y == Math.rint(y) && z == Math.rint(z)
                ? com.sao.engine.SAOWorldSources.refillObject(shell, sourceId, fingerprint,
                    revision, (int) x, (int) y, (int) z) : null;
        } catch (Throwable throwable) {
            SAOAgent.log("worldRefillObject threw: " + throwable);
            return null;
        }
    }

    public boolean worldRefillValid(Object object, Object fixture, String sourceId,
            String fingerprint, double x, double y, double z) {
        try {
            return object instanceof com.sao.engine.SAOIsoPlayerShell shell
                && fixture instanceof zombie.iso.IsoObject source
                && Double.isFinite(x) && Double.isFinite(y) && Double.isFinite(z)
                && x == Math.rint(x) && y == Math.rint(y) && z == Math.rint(z)
                && com.sao.engine.SAOWorldSources.refillValid(shell, source, sourceId,
                    fingerprint, (int) x, (int) y, (int) z);
        } catch (Throwable throwable) {
            SAOAgent.log("worldRefillValid threw: " + throwable);
            return false;
        }
    }

    public String worldPlumbTarget(Object object, String sourceId, String fingerprint,
            String revision, double x, double y, double z) {
        try {
            return object instanceof com.sao.engine.SAOIsoPlayerShell shell
                && Double.isFinite(x) && Double.isFinite(y) && Double.isFinite(z)
                && x == Math.rint(x) && y == Math.rint(y) && z == Math.rint(z)
                ? com.sao.engine.SAOWorldSources.plumbTarget(shell, sourceId, fingerprint,
                    revision, (int) x, (int) y, (int) z) : "BAD_PLUMB_REQUEST";
        } catch (Throwable throwable) {
            SAOAgent.log("worldPlumbTarget threw: " + throwable);
            return "FAILED";
        }
    }

    public Object worldPlumbObject(Object object, String sourceId, String fingerprint,
            String revision, double x, double y, double z) {
        try {
            return object instanceof com.sao.engine.SAOIsoPlayerShell shell
                && Double.isFinite(x) && Double.isFinite(y) && Double.isFinite(z)
                && x == Math.rint(x) && y == Math.rint(y) && z == Math.rint(z)
                ? com.sao.engine.SAOWorldSources.plumbObject(shell, sourceId, fingerprint,
                    revision, (int) x, (int) y, (int) z) : null;
        } catch (Throwable throwable) {
            SAOAgent.log("worldPlumbObject threw: " + throwable);
            return null;
        }
    }

    public boolean worldPlumbValid(Object object, Object fixture, String sourceId,
            String fingerprint, double x, double y, double z, boolean completedConnection) {
        try {
            return object instanceof com.sao.engine.SAOIsoPlayerShell shell
                && fixture instanceof zombie.iso.IsoObject source
                && Double.isFinite(x) && Double.isFinite(y) && Double.isFinite(z)
                && x == Math.rint(x) && y == Math.rint(y) && z == Math.rint(z)
                && com.sao.engine.SAOWorldSources.plumbValid(shell, source, sourceId,
                    fingerprint, (int) x, (int) y, (int) z, completedConnection);
        } catch (Throwable throwable) {
            SAOAgent.log("worldPlumbValid threw: " + throwable);
            return false;
        }
    }

    public String worldGeneratorCandidates(Object object) {
        try { return object instanceof com.sao.engine.SAOIsoPlayerShell shell
            ? com.sao.engine.SAOWorldSources.generatorCandidates(shell) : "";
        } catch (Throwable throwable) { SAOAgent.log("worldGeneratorCandidates threw: " + throwable); return ""; }
    }

    public String worldGeneratorTarget(Object object, String id, String fingerprint, String revision,
            double x, double y, double z, String operation) {
        try { return object instanceof com.sao.engine.SAOIsoPlayerShell shell && integralUtilityCoordinates(x,y,z)
            ? com.sao.engine.SAOWorldSources.generatorTarget(shell,id,fingerprint,revision,(int)x,(int)y,(int)z,operation) : "BAD_GENERATOR_REQUEST";
        } catch (Throwable throwable) { SAOAgent.log("worldGeneratorTarget threw: " + throwable); return "FAILED"; }
    }

    public Object worldGeneratorObject(Object object, String id, String fingerprint, String revision,
            double x, double y, double z, String operation) {
        try { return object instanceof com.sao.engine.SAOIsoPlayerShell shell && integralUtilityCoordinates(x,y,z)
            ? com.sao.engine.SAOWorldSources.generatorObject(shell,id,fingerprint,revision,(int)x,(int)y,(int)z,operation) : null;
        } catch (Throwable throwable) { SAOAgent.log("worldGeneratorObject threw: " + throwable); return null; }
    }

    public boolean worldGeneratorValid(Object object, Object target, String id, String fingerprint,
            double x, double y, double z, String operation) {
        try { return object instanceof com.sao.engine.SAOIsoPlayerShell shell && target instanceof zombie.iso.objects.IsoGenerator generator
            && integralUtilityCoordinates(x,y,z) && com.sao.engine.SAOWorldSources.generatorValid(shell,generator,id,fingerprint,(int)x,(int)y,(int)z,operation);
        } catch (Throwable throwable) { SAOAgent.log("worldGeneratorValid threw: " + throwable); return false; }
    }

    public boolean worldGeneratorConsumerPowered(Object object, Object target, String id, String fingerprint,
            double x, double y, double z) {
        try { return object instanceof com.sao.engine.SAOIsoPlayerShell shell && target instanceof zombie.iso.objects.IsoGenerator generator
            && integralUtilityCoordinates(x,y,z) && com.sao.engine.SAOWorldSources.generatorConsumerPowered(shell,generator,id,fingerprint,(int)x,(int)y,(int)z);
        } catch (Throwable throwable) { SAOAgent.log("worldGeneratorConsumerPowered threw: " + throwable); return false; }
    }

    public String worldGeneratorConsumer(Object object, Object target) {
        try { return object instanceof com.sao.engine.SAOIsoPlayerShell shell && target instanceof zombie.iso.IsoObject consumer
            ? com.sao.engine.SAOWorldSources.generatorConsumer(shell,consumer) : "";
        } catch (Throwable throwable) { SAOAgent.log("worldGeneratorConsumer threw: " + throwable); return ""; }
    }

    private boolean integralUtilityCoordinates(double x, double y, double z) {
        return Double.isFinite(x) && Double.isFinite(y) && Double.isFinite(z)
            && x == Math.rint(x) && y == Math.rint(y) && z == Math.rint(z)
            && Math.abs(x) <= Integer.MAX_VALUE && Math.abs(y) <= Integer.MAX_VALUE && Math.abs(z) <= Integer.MAX_VALUE;
    }

    public String worldGeneratorConsumerTarget(Object object, String id, String fingerprint, String revision,
            double x, double y, double z) {
        try { return object instanceof com.sao.engine.SAOIsoPlayerShell shell && integralUtilityCoordinates(x,y,z)
            ? com.sao.engine.SAOWorldSources.generatorConsumerTarget(shell,id,fingerprint,revision,(int)x,(int)y,(int)z) : "BAD_CONSUMER_REQUEST";
        } catch (Throwable throwable) { SAOAgent.log("worldGeneratorConsumerTarget threw: " + throwable); return "FAILED"; }
    }

    public Object worldGeneratorConsumerObject(Object object, String id, String fingerprint, String revision,
            double x, double y, double z) {
        try { return object instanceof com.sao.engine.SAOIsoPlayerShell shell && integralUtilityCoordinates(x,y,z)
            ? com.sao.engine.SAOWorldSources.generatorConsumerObject(shell,id,fingerprint,revision,(int)x,(int)y,(int)z) : null;
        } catch (Throwable throwable) { SAOAgent.log("worldGeneratorConsumerObject threw: " + throwable); return null; }
    }

    public Object worldShelterSites(Object object,double x,double y,double z) {
        try { return object instanceof com.sao.engine.SAOIsoPlayerShell body && integralUtilityCoordinates(x,y,z)
            ? com.sao.engine.SAOShelterConstruction.observe(body,(int)x,(int)y,(int)z) : null;
        } catch(Throwable t) { SAOAgent.log("worldShelterSites threw: "+t); return null; }
    }
    public Object worldShelterSurfaces(Object object) {
        try { return object instanceof com.sao.engine.SAOIsoPlayerShell body?com.sao.engine.SAOShelterSurface.observe(body):null; }
        catch(Throwable t) { SAOAgent.log("worldShelterSurfaces threw: "+t); return null; }
    }
    public Object worldShelterCoverNeeds(Object object) {
        try { return object instanceof com.sao.engine.SAOIsoPlayerShell body?com.sao.engine.SAOShelterSurface.coverNeeds(body):null; }
        catch(Throwable t) { SAOAgent.log("worldShelterCoverNeeds threw: "+t); return null; }
    }
    public Object worldShelterAccess(Object object) {
        try { return object instanceof com.sao.engine.SAOIsoPlayerShell body?com.sao.engine.SAOShelterSurface.access(body):null; }
        catch(Throwable t) { SAOAgent.log("worldShelterAccess threw: "+t); return null; }
    }
    public Object worldShelterSurfacePlacementSquare(Object object,String key,String revision) {
        try { return object instanceof com.sao.engine.SAOIsoPlayerShell body?com.sao.engine.SAOShelterSurface.placement(body,key,revision):null; }
        catch(Throwable t) { SAOAgent.log("worldShelterSurfacePlacementSquare threw: "+t); return null; }
    }
    public boolean worldShelterSurfaceCreated(Object object,Object created,String entity,double x,double y,double z) {
        try { return object instanceof com.sao.engine.SAOIsoPlayerShell body&&created instanceof zombie.iso.IsoObject part&&integralUtilityCoordinates(x,y,z)
            &&com.sao.engine.SAOShelterSurface.created(body,part,entity,(int)x,(int)y,(int)z); }
        catch(Throwable t) { SAOAgent.log("worldShelterSurfaceCreated threw: "+t); return false; }
    }
    public Object worldShelterPlacementSquare(Object object,String key,String revision) {
        try { return object instanceof com.sao.engine.SAOIsoPlayerShell body
            ? com.sao.engine.SAOShelterConstruction.placement(body,key,revision) : null;
        } catch(Throwable t) { SAOAgent.log("worldShelterPlacementSquare threw: "+t); return null; }
    }
    public Object worldShelterPreviousStage(Object object,String key,String revision) {
        try { return object instanceof com.sao.engine.SAOIsoPlayerShell body
            ? com.sao.engine.SAOShelterConstruction.previous(body,key,revision) : null;
        } catch(Throwable t) { SAOAgent.log("worldShelterPreviousStage threw: "+t); return null; }
    }
    public Object worldShelterDoor(Object object,String key,String revision) {
        try { return object instanceof com.sao.engine.SAOIsoPlayerShell body
            ? com.sao.engine.SAOShelterConstruction.door(body,key,revision) : null;
        } catch(Throwable t) { SAOAgent.log("worldShelterDoor threw: "+t); return null; }
    }
    public boolean worldShelterCreated(Object object,Object created,Object previous,String entityId,double x,double y,double z,String face) {
        try { return object instanceof com.sao.engine.SAOIsoPlayerShell body && created instanceof zombie.iso.objects.IsoThumpable item
            && (previous==null||previous instanceof zombie.iso.IsoObject) && integralUtilityCoordinates(x,y,z)
            && com.sao.engine.SAOShelterConstruction.created(body,item,(zombie.iso.IsoObject)previous,entityId,(int)x,(int)y,(int)z,face);
        } catch(Throwable t) { SAOAgent.log("worldShelterCreated threw: "+t); return false; }
    }
    public String worldShelterBeginPassage(Object object,Object door,String key,String revision,boolean inward) {
        try { return object instanceof com.sao.engine.SAOIsoPlayerShell body && door instanceof zombie.iso.IsoObject item
            ? com.sao.engine.SAOShelterConstruction.beginPassage(body,item,key,revision,inward) : null;
        } catch(Throwable t) { SAOAgent.log("worldShelterBeginPassage threw: "+t); return null; }
    }
    public boolean worldShelterPassage(Object object,String token) {
        try { return object instanceof com.sao.engine.SAOIsoPlayerShell body && token!=null
            && com.sao.engine.SAOShelterConstruction.passage(body,token);
        } catch(Throwable t) { SAOAgent.log("worldShelterPassage threw: "+t); return false; }
    }
    public boolean worldShelterForgetPassage(Object object,String token) {
        try { if(object instanceof com.sao.engine.SAOIsoPlayerShell body && token!=null){
            com.sao.engine.SAOShelterConstruction.forgetPassage(body,token);return true; } return false;
        } catch(Throwable t) { SAOAgent.log("worldShelterForgetPassage threw: "+t); return false; }
    }
    public boolean worldShelterRecoveryValid(Object object,String key,String revision,double x,double y,double z,boolean reached) {
        try { return object instanceof com.sao.engine.SAOIsoPlayerShell body && key!=null && revision!=null
            && Double.isFinite(x)&&Double.isFinite(y)&&Double.isFinite(z)
            && com.sao.engine.SAOShelterConstruction.recoveryValid(body,key,revision,x,y,z,reached);
        } catch(Throwable t) { SAOAgent.log("worldShelterRecoveryValid threw: "+t); return false; }
    }
    public Object worldShelterCover(Object object,double x,double y,double z) {
        try { return object instanceof com.sao.engine.SAOIsoPlayerShell body && integralUtilityCoordinates(x,y,z)
            ? com.sao.engine.SAOShelterConstruction.cover(body,(int)x,(int)y,(int)z) : null;
        } catch(Throwable t) { SAOAgent.log("worldShelterCover threw: "+t); return null; }
    }

    public String worldBedSites(Object object) {
        try { return object instanceof com.sao.engine.SAOIsoPlayerShell body
            ? com.sao.engine.SAOBedConstruction.observe(body) : "";
        } catch(Throwable t) { SAOAgent.log("worldBedSites threw: "+t); return ""; }
    }
    public Object worldBedPlacementSquare(Object object,double x,double y,double z,String face,String revision) {
        try { return object instanceof com.sao.engine.SAOIsoPlayerShell body
            && Double.isFinite(x)&&Double.isFinite(y)&&Double.isFinite(z)
            && x==Math.rint(x)&&y==Math.rint(y)&&z==Math.rint(z)
            ? com.sao.engine.SAOBedConstruction.placement(body,(int)x,(int)y,(int)z,face,revision) : null;
        } catch(Throwable t) { SAOAgent.log("worldBedPlacementSquare threw: "+t); return null; }
    }
    public boolean worldBedCreated(Object object,Object first,Object second,double x,double y,double z,String face) {
        try { return object instanceof com.sao.engine.SAOIsoPlayerShell body
            && first instanceof zombie.iso.objects.IsoThumpable a && second instanceof zombie.iso.objects.IsoThumpable b
            && Double.isFinite(x)&&Double.isFinite(y)&&Double.isFinite(z)
            && x==Math.rint(x)&&y==Math.rint(y)&&z==Math.rint(z)
            && com.sao.engine.SAOBedConstruction.created(body,a,b,(int)x,(int)y,(int)z,face);
        } catch(Throwable t) { SAOAgent.log("worldBedCreated threw: "+t); return false; }
    }

    public String worldCollectorSites(Object object) {
        try {
            return object instanceof com.sao.engine.SAOIsoPlayerShell shell
                ? com.sao.engine.SAOWorldSources.collectorSites(shell) : "";
        } catch (Throwable throwable) {
            SAOAgent.log("worldCollectorSites threw: " + throwable);
            return "";
        }
    }

    public Object worldCollectorPlacementSquare(Object object, double x, double y,
            double z, String revision) {
        try {
            return object instanceof com.sao.engine.SAOIsoPlayerShell shell
                && Double.isFinite(x) && Double.isFinite(y) && Double.isFinite(z)
                && x == Math.rint(x) && y == Math.rint(y) && z == Math.rint(z)
                ? com.sao.engine.SAOWorldSources.collectorPlacementSquare(shell,
                    (int) x, (int) y, (int) z, revision) : null;
        } catch (Throwable throwable) {
            SAOAgent.log("worldCollectorPlacementSquare threw: " + throwable);
            return null;
        }
    }

    public boolean worldCollectorCreated(Object object, Object created, String entityId,
            double x, double y, double z) {
        try {
            return object instanceof com.sao.engine.SAOIsoPlayerShell shell
                && created instanceof zombie.iso.objects.IsoThumpable collector
                && Double.isFinite(x) && Double.isFinite(y) && Double.isFinite(z)
                && x == Math.rint(x) && y == Math.rint(y) && z == Math.rint(z)
                && com.sao.engine.SAOWorldSources.collectorCreated(shell, collector,
                    entityId, (int) x, (int) y, (int) z);
        } catch (Throwable throwable) {
            SAOAgent.log("worldCollectorCreated threw: " + throwable);
            return false;
        }
    }

    public String worldCollectorSource(Object object, Object created, String entityId,
            double x, double y, double z) {
        try {
            return object instanceof com.sao.engine.SAOIsoPlayerShell shell
                && created instanceof zombie.iso.objects.IsoThumpable collector
                && Double.isFinite(x) && Double.isFinite(y) && Double.isFinite(z)
                && x == Math.rint(x) && y == Math.rint(y) && z == Math.rint(z)
                ? com.sao.engine.SAOWorldSources.collectorSource(shell, collector,
                    entityId, (int) x, (int) y, (int) z) : "";
        } catch (Throwable throwable) {
            SAOAgent.log("worldCollectorSource threw: " + throwable);
            return "";
        }
    }

    public boolean worldCollectorFeedsFixture(Object object, Object created, String sourceId,
            String fingerprint, double x, double y, double z) {
        try {
            return object instanceof com.sao.engine.SAOIsoPlayerShell shell
                && created instanceof zombie.iso.objects.IsoThumpable collector
                && Double.isFinite(x) && Double.isFinite(y) && Double.isFinite(z)
                && x == Math.rint(x) && y == Math.rint(y) && z == Math.rint(z)
                && com.sao.engine.SAOWorldSources.collectorFeedsFixture(shell, collector,
                    sourceId, fingerprint, (int) x, (int) y, (int) z);
        } catch (Throwable throwable) {
            SAOAgent.log("worldCollectorFeedsFixture threw: " + throwable);
            return false;
        }
    }

    /** [C62] Final identity, reach and vehicle-part permission proof. */
    public String bindWorldSourceAction(Object object, String sourceId,
            String fingerprint, String revision, double itemId, String itemType,
            double x, double y, double z) {
        try {
            if (object instanceof com.sao.engine.SAOIsoPlayerShell shell) {
                return com.sao.engine.SAOWorldSources.bindAction(shell,
                    sourceId, fingerprint, revision, (int) itemId, itemType,
                    (int) x, (int) y, (int) z);
            }
            return "NO_LIVE_BODY";
        } catch (Throwable throwable) {
            SAOAgent.log("bindWorldSourceAction threw: " + throwable);
            return "FAILED";
        }
    }

    public Object worldSourceActionItem(Object object) {
        return object instanceof com.sao.engine.SAOIsoPlayerShell shell
            ? com.sao.engine.SAOWorldSources.actionItem(shell) : null;
    }

    public Object worldSourceActionContainer(Object object) {
        return object instanceof com.sao.engine.SAOIsoPlayerShell shell
            ? com.sao.engine.SAOWorldSources.actionSourceContainer(shell) : null;
    }

    public Object worldSourceActionOriginContainer(Object object) {
        return object instanceof com.sao.engine.SAOIsoPlayerShell shell
            ? com.sao.engine.SAOWorldSources.actionOriginContainer(shell) : null;
    }

    public String worldTransferPosition(Object object, Object containerObject) {
        return object instanceof com.sao.engine.SAOIsoPlayerShell shell
            && containerObject instanceof zombie.inventory.ItemContainer container
            ? com.sao.engine.SAOWorldSources.transferPosition(shell, container) : "";
    }

    public String worldTransferOffer(Object object, Object itemObject,
            Object containerObject, String operation) {
        return object instanceof com.sao.engine.SAOIsoPlayerShell shell
            && itemObject instanceof zombie.inventory.InventoryItem item
            && containerObject instanceof zombie.inventory.ItemContainer container
            ? com.sao.engine.SAOWorldSources.transferOffer(shell, item, container,
                operation) : "";
    }

    public String worldStoreActionTarget(Object object, String sourceId,
            String fingerprint, String revision, double itemId, String itemType,
            double x, double y, double z) {
        return object instanceof com.sao.engine.SAOIsoPlayerShell shell
            ? com.sao.engine.SAOWorldSources.storeActionTarget(shell, sourceId,
                fingerprint, revision, (int) itemId, itemType,
                (int) x, (int) y, (int) z) : "NO_LIVE_BODY";
    }

    public String bindWorldStoreAction(Object object, String sourceId,
            String fingerprint, String revision, double itemId, String itemType,
            double x, double y, double z) {
        return object instanceof com.sao.engine.SAOIsoPlayerShell shell
            ? com.sao.engine.SAOWorldSources.bindStoreAction(shell, sourceId,
                fingerprint, revision, (int) itemId, itemType,
                (int) x, (int) y, (int) z) : "NO_LIVE_BODY";
    }

    public String worldStoreTransferState(Object object, String sourceId,
            String fingerprint, double itemId, String itemType,
            double x, double y, double z) {
        return object instanceof com.sao.engine.SAOIsoPlayerShell shell
            ? com.sao.engine.SAOWorldSources.storeTransferState(shell, sourceId,
                fingerprint, (int) itemId, itemType,
                (int) x, (int) y, (int) z) : "UNAVAILABLE";
    }

    public Object worldSourceActionPermissionContainer(Object object) {
        return object instanceof com.sao.engine.SAOIsoPlayerShell shell
            ? com.sao.engine.SAOWorldSources.actionPermissionContainer(shell) : null;
    }

    public Object worldSourceActionWorldItem(Object object) {
        return object instanceof com.sao.engine.SAOIsoPlayerShell shell
            ? com.sao.engine.SAOWorldSources.actionWorldItem(shell) : null;
    }

    public Object carriedWorldSourceItem(Object object, double itemId,
            String itemType) {
        return object instanceof com.sao.engine.SAOIsoPlayerShell shell
            ? com.sao.engine.SAOWorldSources.carriedActionItem(shell,
                (int) itemId, itemType) : null;
    }

    public String carriedWorldTransferItem(Object object, double itemId,
            String itemType) {
        return object instanceof com.sao.engine.SAOIsoPlayerShell shell
            ? com.sao.engine.SAOWorldSources.carriedTransferItem(shell,
                (int) itemId, itemType) : "";
    }

    public double carriedWorldSourceMeasure(Object object, double itemId,
            String itemType, String category) {
        return object instanceof com.sao.engine.SAOIsoPlayerShell shell
            ? com.sao.engine.SAOWorldSources.carriedActionMeasure(shell,
                (int) itemId, itemType, category) : -1.0;
    }

    public boolean beginWorldSourceUse(Object object, double itemId,
            String itemType, String category, double durableBaseline) {
        return object instanceof com.sao.engine.SAOIsoPlayerShell shell
            && com.sao.engine.SAOWorldSources.beginUse(shell, (int) itemId,
                itemType, category, (float) durableBaseline);
    }

    public String finishWorldSourceUse(Object object, boolean completed) {
        return object instanceof com.sao.engine.SAOIsoPlayerShell shell
            ? com.sao.engine.SAOWorldSources.finishUse(shell, completed)
            : "NO_EFFECT:0:no-live-body";
    }

    public void clearWorldSourceAction(Object object) {
        if (object instanceof com.sao.engine.SAOIsoPlayerShell shell) {
            com.sao.engine.SAOWorldSources.clearAction(shell);
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

    /**
     * [C73] The shell takes the record's sex as well as its name.
     *
     * `spawnShellNamed` stamps a real forename onto the descriptor and
     * refuses the placeholders ([C3]). The descriptor's SEX came from
     * `CreateSurvivor`, which draws its own, so a record named Rosa could
     * be given a male body and there was nothing to notice it with. The
     * record decides now, and the name it carries was drawn against the
     * same fact (DR-039).
     *
     * The old arity stays and defers to the engine's own draw, because
     * the Knox adoption edge takes a person who arrives already made.
     */
    public IsoPlayer spawnShellNamed(String forename, String surname, double dx, double dy, double dz) {
        return spawnShellNamed(forename, surname, dx, dy, dz, null);
    }

    public IsoPlayer spawnShellNamed(String forename, String surname, double dx, double dy, double dz, Object female) {
        return spawnShellNamed(forename, surname, dx, dy, dz, female, true);
    }

    /** Body defers population accounting until restoration has succeeded. */
    public IsoPlayer spawnShellNamed(String forename, String surname, double dx, double dy, double dz, Object female, boolean accountNow) {
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
            // Before the name, because the name was drawn against it.
            if (female instanceof Boolean) {
                desc.setFemale((Boolean) female);
            }
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
            if (accountNow) accountShell(shell);
            SAOAgent.log("shell up at " + x + "," + y + "," + z
                + " playerIndex=" + shell.playerIndex
                + " for " + forename + " " + surname);
            return shell;
        } catch (Throwable throwable) {
            SAOAgent.log("spawnShellNamed threw: " + throwable);
            return null;
        }
    }

    /** The existing population exchange occurs once, after a usable body exists. */
    public void accountShell(Object object) {
        try {
            if (!(object instanceof SAOIsoPlayerShell shell)
                    || shell.populationAccounted || shell.removalPending) return;
            shell.populationAccounted = true;
            boolean taken = takeFromThePool(shell.getCell(), (int) shell.getX(),
                (int) shell.getY(), (int) shell.getZ(), 12);
            SAOAgent.log("shell population exchange=" + taken);
        } catch (Throwable throwable) {
            SAOAgent.log("shell population accounting failed: " + throwable);
        }
    }

    public boolean removeShell(Object object) {
        if (!(object instanceof SAOIsoPlayerShell shell)) {
            SAOAgent.log("removeShell refused: not an SAO shell");
            return false;
        }
        try {
            if (!shell.removalPending && !canReleaseShell(shell)) return false;
            shell.removalPending = true;
            shell.setGhostMode(true);
            shell.setZombiesDontAttack(true);
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

    /** Native inventory-transfer facing, independent of a player loot panel. */
    public boolean faceTransferContainer(Object object, Object container) {
        try {
            if (!(object instanceof SAOIsoPlayerShell shell)
                    || !(container instanceof zombie.inventory.ItemContainer source)) return false;
            zombie.iso.IsoObject parent = source.getParent();
            if (parent != null && !shell.isSittingOnFurniture()) shell.faceThisObject(parent);
            return true;
        } catch (Throwable error) {
            SAOAgent.log("transfer facing refused: " + error);
            return false;
        }
    }

    /** A live owned shell whose native world attachment has ended. Native chunk
     * unloading removes the body from the cell and clears its current square.
     * A missing square alone also occurs during admission or movement, while a
     * staged/captured body is deliberately detached and belongs to its existing
     * transaction. This reads attachment state; it does not infer an unload cause
     * or interrupt, remove, or otherwise change the shell.
     */
    public boolean isShellUnloaded(Object object) {
        try {
            if (!(object instanceof SAOIsoPlayerShell shell)
                    || shell.removalPending || shell.getCurrentSquare() != null) return false;
            IsoWorld world = IsoWorld.instance;
            IsoCell cell = world == null ? null : world.getCell();
            if (cell == null || cell.getObjectList() == null || cell.getAddList() == null) return false;
            return !cell.getObjectList().contains(shell) && !cell.getAddList().contains(shell);
        } catch (Throwable throwable) {
            SAOAgent.log("isShellUnloaded threw: " + throwable);
            return false;
        }
    }

    // ------------------------------------------------------------------

    private static void removeShellInternal(SAOIsoPlayerShell shell) throws java.io.IOException {
        // Spawn rollback enters here directly, before a body is published to
        // the Lua owner. Every teardown path must suppress native updates.
        shell.removalPending = true;
        try {
            clearMovementIntent(shell);
        } catch (Throwable ignored) {
            // teardown continues regardless
        }
        com.sao.engine.SAONativeSnapshot.unregister(shell);
        ModelManager.instance.Remove((IsoGameCharacter) shell);
        shell.setMovingSquare(null);
        shell.removeFromSquare();
        shell.removeFromWorld();
        shell.retireNativeDescriptor();
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
