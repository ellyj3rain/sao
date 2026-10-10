package com.sao.engine;

import com.sao.agent.SAOAgent;
import com.sao.agent.SAOLootDensityWeave;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.UUID;
import java.util.WeakHashMap;
import zombie.characters.CharacterStat;
import zombie.characters.IsoPlayer;
import zombie.core.Core;
import zombie.entity.components.fluids.Fluid;
import zombie.entity.components.fluids.FluidContainer;
import zombie.inventory.InventoryItem;
import zombie.inventory.ItemContainer;
import zombie.inventory.ItemPickerJava;
import zombie.inventory.types.InventoryContainer;
import zombie.iso.BuildingDef;
import zombie.iso.IsoCell;
import zombie.iso.IsoChunk;
import zombie.iso.IsoChunkMap;
import zombie.iso.IsoGridSquare;
import zombie.iso.IsoObject;
import zombie.iso.IsoWorld;
import zombie.iso.WorldStreamer;
import zombie.iso.objects.IsoWorldInventoryObject;
import zombie.iso.objects.IsoThumpable;
import zombie.iso.objects.IsoGenerator;
import zombie.network.GameClient;
import zombie.network.GameServer;
import zombie.vehicles.BaseVehicle;
import zombie.vehicles.VehiclePart;

/**
 * R10a's native ground transaction.
 *
 * A meta-grid building says where a source may exist. This class is the first
 * place that answers what exists: it loads one real PZ chunk under the normal
 * chunk lifecycle, asks ItemPickerJava to populate unexplored containers,
 * records exact native identities and contents, synchronously saves, and then
 * removes an off-screen chunk from the live world. Loaded chunks are observed
 * in place. It never creates an SAO inventory or rolls a distribution itself.
 *
 * The text protocol deliberately contains observations only. Durable state,
 * reservations, private knowledge, and result ownership live in Lua ModData.
 */
public final class SAOWorldSources {
    private static final String PROTOCOL = "SAOWS1";
    private static final String SOURCE_TOKEN = "SAOWorldSourceId";
    private static final String ITEM_TOKEN = "SAOWorldItemSourceId";
    private static final int MAX_SOURCES_PER_CHUNK = 2048;
    private static final int MAX_ITEMS_PER_SOURCE = 2048;
    private static final int MAX_CONTAINER_DEPTH = 16;
    private static final int MAX_INSPECTION_OPTIONS = 128;
    private static final int INSPECTION_RANGE = 14;
    private static final int CHUNK_SIZE = IsoChunkMap.CHUNK_SIZE_IN_SQUARES;
    private static final ThreadLocal<Integer> HYDRATION_DEPTH =
        ThreadLocal.withInitial(() -> 0);
    private static final Map<IsoPlayer, ActionBinding> ACTIONS =
        new WeakHashMap<>();
    private static final Map<IsoPlayer, Map<String, InspectionBinding>> INSPECTIONS =
        new WeakHashMap<>();
    private static final Map<IsoPlayer, se.krka.kahlua.vm.KahluaTable> INSPECTION_MEMORY =
        new WeakHashMap<>();
    private static final Map<IsoPlayer, LinkedHashMap<String, CollectorSiteBinding>> COLLECTOR_SITES =
        new WeakHashMap<>();
    private static final Map<IsoPlayer, Map<String, UtilityBinding>> UTILITY_BINDINGS = new WeakHashMap<>();
    private static boolean transactionActive;

    private SAOWorldSources() {
    }

    /** Read by the density advice from inside ItemPickerJava. */
    public static boolean isHydrating() {
        return HYDRATION_DEPTH.get() > 0;
    }

    public static String status() {
        return "protocol=" + PROTOCOL + "|" + SAOLootDensityWeave.report()
            + "|hydrating=" + isHydrating();
    }

    /** Drop body-keyed exact-source bindings when the owning world ends. */
    public static synchronized void resetRuntimeForWorld() {
        ACTIONS.clear();
        INSPECTIONS.clear();
        INSPECTION_MEMORY.clear();
        COLLECTOR_SITES.clear();
        UTILITY_BINDINGS.clear();
    }

    /** Kahlua does not implement Lua weak tables. Keep body keys on the JVM;
     * the returned table contains only data, never a native body or holder. */
    public static synchronized Object inspectionMemory(IsoPlayer shell) {
        if (!inspectionActor(shell)) return null;
        return INSPECTION_MEMORY.computeIfAbsent(shell,
            ignored -> zombie.Lua.LuaManager.platform.newTable());
    }

    /** Personally visible loose material, through the existing exact source protocol. */
    public static synchronized ArrayList<String> visibleGroundSources(IsoPlayer shell, int radius) {
        ArrayList<String> out = new ArrayList<>();
        if (transactionActive || !inspectionActor(shell) || radius < 1 || radius > INSPECTION_RANGE) return out;
        try {
            IsoCell cell = shell.getCell();
            int x = (int) Math.floor(shell.getX()), y = (int) Math.floor(shell.getY());
            int z = (int) Math.floor(shell.getZ());
            ArrayList<Source> seen = new ArrayList<>();
            for (int dy = -radius; dy <= radius; dy++) for (int dx = -radius; dx <= radius; dx++) {
                IsoGridSquare square = cell.getGridSquare(x + dx, y + dy, z);
                if (!SAOPerceptionScanner.canSeeWorldSquareNow(shell, square, radius)) continue;
                for (IsoWorldInventoryObject world : new ArrayList<>(square.getWorldObjects())) {
                    InventoryItem item = world == null ? null : world.getItem();
                    if (item == null || world.getSquare() != square || item.getWorldItem() != world) continue;
                    Snapshot snapshot = new Snapshot(Math.floorDiv(square.getX(), CHUNK_SIZE), Math.floorDiv(square.getY(), CHUNK_SIZE));
                    Source source = groundSource(snapshot, square, world);
                    int at = Collections.binarySearch(seen, source, Comparator.comparingDouble((Source row) ->
                        Math.pow(row.x + 0.5 - shell.getX(), 2) + Math.pow(row.y + 0.5 - shell.getY(), 2))
                        .thenComparing(row -> row.id));
                    if (at < 0) at = -at - 1;
                    if (at < 32) { seen.add(at, source); if (seen.size() > 32) seen.remove(32); }
                }
            }
            for (Source source : seen) {
                Snapshot snapshot = new Snapshot(Math.floorDiv(source.x, CHUNK_SIZE), Math.floorDiv(source.y, CHUNK_SIZE));
                snapshot.mode = "visible-ground";
                snapshot.add(source); snapshot.finish(); out.add(encode(snapshot));
            }
        } catch (Throwable unavailable) { out.clear(); }
        return out;
    }

    /** Visible holder geometry only: listing never reads or generates contents. */
    public static synchronized String inspectionCandidates(IsoPlayer shell, int radius) {
        if (transactionActive || !inspectionActor(shell) || radius < 1
                || radius > INSPECTION_RANGE) return "";
        try {
            IsoCell cell = shell.getCell();
            int x = (int) Math.floor(shell.getX()), y = (int) Math.floor(shell.getY());
            int z = (int) Math.floor(shell.getZ());
            ArrayList<InspectionBinding> candidates = new ArrayList<>();
            for (int dy = -radius; dy <= radius; dy++) {
                for (int dx = -radius; dx <= radius; dx++) {
                    IsoGridSquare square = cell.getGridSquare(x + dx, y + dy, z);
                    if (!SAOPerceptionScanner.canSeeWorldSquareNow(shell, square, radius)) continue;
                    IsoGridSquare approach = interactionSquare(shell, square);
                    if (approach == null) continue;
                    List<IsoObject> objects = square.getObjects();
                    for (int objectIndex = 0; objectIndex < objects.size(); objectIndex++) {
                        IsoObject object = objects.get(objectIndex);
                        if (object == null || object.getSquare() != square
                                || (object instanceof IsoThumpable locked
                                    && locked.isLockedToCharacter(shell))) continue;
                        for (int index = 0; index < object.getContainerCount(); index++) {
                            ItemContainer container = object.getContainerByIndex(index);
                            if (container == null || container.getParent() != object
                                    || container.getSourceGrid() != square
                                    || container.getOutermostContainer() != container) continue;
                            String id = privateContainerId(object, index);
                            String token = id.split(":")[1];
                            String fingerprint = containerFingerprint(square, object, container, index, token);
                            var candidate = new InspectionBinding(id, fingerprint, object, container,
                                index, square, approach, shell);
                            int at = Collections.binarySearch(candidates, candidate,
                                Comparator.comparingDouble((InspectionBinding item) -> item.distance)
                                    .thenComparing(item -> item.id));
                            if (at < 0) at = -at - 1;
                            if (at < MAX_INSPECTION_OPTIONS) {
                                candidates.add(at, candidate);
                                if (candidates.size() > MAX_INSPECTION_OPTIONS) {
                                    candidates.remove(MAX_INSPECTION_OPTIONS);
                                }
                            }
                        }
                    }
                }
            }
            Map<String, InspectionBinding> bindings = new LinkedHashMap<>();
            StringBuilder out = new StringBuilder("H|protocol=SAOWI1\n");
            for (InspectionBinding candidate : candidates) {
                if (bindings.put(candidate.id, candidate) != null) {
                    INSPECTIONS.remove(shell);
                    return "";
                }
                out.append("C|id=").append(field(candidate.id))
                    .append("|fp=").append(candidate.fingerprint)
                    .append("|sx=").append(candidate.sourceX)
                    .append("|sy=").append(candidate.sourceY)
                    .append("|sz=").append(candidate.sourceZ)
                    .append("|x=").append(candidate.x)
                    .append("|y=").append(candidate.y)
                    .append("|z=").append(candidate.z)
                    .append("|reachable=").append(SAONeeds.containerAccessibleNow(shell,
                        candidate.container.get()) ? 1 : 0).append('\n');
            }
            INSPECTIONS.put(shell, bindings);
            return out.append("E\n").toString();
        } catch (Throwable unavailable) {
            INSPECTIONS.remove(shell);
            SAOAgent.log("world inspection candidates threw: " + unavailable);
            return "";
        }
    }

    /** Caller owns current social permission; this owns exact native access and loot opening. */
    public static synchronized String inspectContainer(IsoPlayer shell, String sourceId,
            String fingerprint, int x, int y, int z) {
        if (transactionActive) return "BUSY";
        if (!inspectionActor(shell)) return "NO_LIVE_BODY";
        if (GameClient.client || GameServer.server) return "SERVER_AUTHORITY_REQUIRED";
        var bindings = INSPECTIONS.get(shell);
        InspectionBinding binding = bindings == null ? null : bindings.get(sourceId);
        if (binding == null || !binding.fingerprint.equals(fingerprint)) return "NOT_OFFERED";
        transactionActive = true;
        try {
            IsoGridSquare square = shell.getCell().getGridSquare(x, y, z);
            IsoObject object = binding.object.get();
            ItemContainer container = binding.container.get();
            if (object == null || container == null || square == null
                    || square != binding.square.get() || object.getSquare() != square
                    || !square.getObjects().contains(object)
                    || binding.index >= object.getContainerCount()
                    || object.getContainerByIndex(binding.index) != container
                    || container.getParent() != object || container.getSourceGrid() != square
                    || !sourceId.equals(privateContainerId(object, binding.index))
                    || !fingerprint.equals(containerFingerprint(square, object, container,
                        binding.index, sourceId.split(":")[1]))) return "SOURCE_CHANGED";
            if ((object instanceof IsoThumpable locked && locked.isLockedToCharacter(shell))
                    || !SAONeeds.containerAccessibleNow(shell, container)) return "ACCESS_REFUSED";
            IsoChunk chunk = square.getChunk();
            if (chunk == null || shell.getCell().getChunk(chunk.wx, chunk.wy) != chunk) {
                return "NOT_LOADED";
            }
            // ISInventoryPage.checkExplored: native fill uses the actual opener.
            // An attempted roll is terminal even if a mod throws partway through;
            // do not roll it twice. No successful inspection is emitted on error.
            if (!container.isExplored()) {
                try { ItemPickerJava.fillContainer(container, shell); }
                finally { container.setExplored(true); }
            }
            Snapshot snapshot = scan(chunk, false);
            Source source = snapshot.byId.get(sourceId);
            if (source == null || !source.explored
                    || !fingerprint.equals(source.fingerprint)) return "SOURCE_CHANGED";
            binding.observedRevision = source.revision;
            return "I|source=" + field(sourceId) + "\n" + encode(snapshot);
        } catch (Throwable unavailable) {
            SAOAgent.log("world container inspection threw: " + unavailable);
            return "INSPECTION_FAILED";
        } finally {
            transactionActive = false;
        }
    }

    private static boolean inspectionActor(IsoPlayer shell) {
        return shell != null && !shell.isDead() && !shell.isAsleep()
            && shell.getCell() != null && shell.getCell() == currentCell()
            && shell.getCurrentSquare() != null
            && shell.getCell().getGridSquare((int) Math.floor(shell.getX()),
                (int) Math.floor(shell.getY()), (int) Math.floor(shell.getZ()))
                == shell.getCurrentSquare();
    }

    /** An explored bit belongs to the world, not to every person's knowledge.
     * Only exact private evidence can expose items through a decision view. */
    static synchronized boolean knowsContainerContents(IsoPlayer person,
            IsoObject object, ItemContainer container, int index) {
        try {
            if (person == null || object == null || container == null
                    || !container.isExplored() || object.getContainerByIndex(index) != container
                    || container.getParent() != object) return false;
            IsoGridSquare square = object.getSquare();
            if (square == null || square.getCell() != person.getCell()) return false;
            String id = privateContainerId(object, index);
            String token = id.split(":")[1];
            String fingerprint = containerFingerprint(square, object, container, index, token);
            var bindings = INSPECTIONS.get(person);
            InspectionBinding own = bindings == null ? null : bindings.get(id);
            String observed = own != null && own.object.get() == object
                && own.container.get() == container && own.fingerprint.equals(fingerprint)
                ? own.observedRevision : null;
            var remembered = rememberedContainerRevisions(person, id, fingerprint);
            if (observed == null && remembered.isEmpty()) return false;
            String current = containerSourceKnown(square, object, container, index, token).revision;
            return current.equals(observed) || remembered.contains(current);
        } catch (Throwable unavailable) {
            return false;
        }
    }

    private static se.krka.kahlua.vm.KahluaTable table(Object value) {
        return value instanceof se.krka.kahlua.vm.KahluaTable result ? result : null;
    }

    private static java.util.Set<String> rememberedContainerRevisions(IsoPlayer person, String id,
            String fingerprint) {
        var revisions = new java.util.HashSet<String>();
        var env = zombie.Lua.LuaManager.env;
        var sao = env == null ? null : table(env.rawget("SAO"));
        var perception = sao == null ? null : table(sao.rawget("Perception"));
        var beliefs = perception == null ? null : table(perception.rawget("beliefs"));
        Object personId = person.getModData().rawget("SAOPersonId");
        var mind = beliefs == null || !(personId instanceof String)
            ? null : table(beliefs.rawget(personId));
        var known = mind == null ? null : table(mind.rawget("known"));
        if (known == null) return revisions;
        var places = known.iterator();
        while (places.advance()) {
            var place = table(places.getValue());
            var facts = place == null ? null : table(place.rawget("sourceFacts"));
            var fact = facts == null ? null : table(facts.rawget(id));
            if (fact != null && fingerprint.equals(fact.rawget("fingerprint"))
                    && Boolean.TRUE.equals(fact.rawget("explored"))
                    && ("available".equals(fact.rawget("state")) || "spent".equals(fact.rawget("state")))
                    && fact.rawget("revision") instanceof String revision) revisions.add(revision);
        }
        return revisions;
    }

    /**
     * Resolve an observed identity back to the current loaded engine object
     * and select one reachable interaction square. This proves identity and
     * revision only; bindAction performs the actor-specific access proof after
     * locomotion reaches the returned square.
     */
    public static synchronized String actionTarget(IsoPlayer shell, String sourceId,
            String fingerprint, String revision, int itemId, String itemType,
            int expectedX, int expectedY, int expectedZ) {
        try {
            Located located = locate(shell, sourceId, fingerprint, revision,
                itemId, itemType, expectedX, expectedY, expectedZ);
            IsoGridSquare target = located.vehicle == null
                ? interactionSquare(shell, located.square)
                : vehicleInteractionSquare(located.vehicle, located.vehiclePart);
            if (target == null) return "NO_INTERACTION_POINT";
            return "READY:" + target.getX() + ":" + target.getY() + ":"
                + target.getZ() + ":" + located.square.getX() + ":"
                + located.square.getY() + ":" + located.square.getZ();
        } catch (ActionRefusal refusal) {
            return refusal.code;
        } catch (Throwable throwable) {
            SAOAgent.log("world source target threw: " + throwable);
            return "FAILED";
        }
    }

    /** Refill a carried vessel from an exact privately remembered fluid fixture. */
    public static synchronized String refillTarget(IsoPlayer shell, String sourceId,
            String fingerprint, String revision, int x, int y, int z) {
        try {
            if (revision == null || revision.isBlank()) return "BAD_REFILL_REQUEST";
            IsoObject object = refillFixture(shell, sourceId, fingerprint, revision, x, y, z);
            IsoGridSquare target = interactionSquare(shell, object.getSquare());
            if (target == null) return "NO_INTERACTION_POINT";
            return "READY:" + target.getX() + ":" + target.getY() + ":" + target.getZ();
        } catch (ActionRefusal refusal) { return refusal.code; }
        catch (Throwable unavailable) {
            SAOAgent.log("world refill target threw: " + unavailable);
            return "FAILED";
        }
    }

    public static synchronized Object refillObject(IsoPlayer shell, String sourceId,
            String fingerprint, String revision, int x, int y, int z) {
        try {
            if (revision == null || revision.isBlank()) return null;
            IsoObject object = refillFixture(shell, sourceId, fingerprint, revision, x, y, z);
            return refillWithinReach(shell, object.getSquare()) ? object : null;
        } catch (ActionRefusal refusal) { return null; }
        catch (Throwable unavailable) {
            SAOAgent.log("world refill object threw: " + unavailable);
            return null;
        }
    }

    /** Own transfer changes the fluid revision; physical identity and access remain exact. */
    public static synchronized boolean refillValid(IsoPlayer shell, IsoObject object,
            String sourceId, String fingerprint, int x, int y, int z) {
        try {
            return refillFixture(shell, sourceId, fingerprint, null, x, y, z) == object
                && refillWithinReach(shell, object.getSquare());
        } catch (ActionRefusal refusal) { return false; }
        catch (Throwable unavailable) {
            SAOAgent.log("world refill validation threw: " + unavailable);
            return false;
        }
    }

    private static IsoObject refillFixture(IsoPlayer shell, String sourceId,
            String fingerprint, String revision, int x, int y, int z) throws ActionRefusal {
        if (!inspectionActor(shell) || sourceId == null || !sourceId.startsWith("F:")
                || sourceId.length() <= 2) throw new ActionRefusal("BAD_REFILL_REQUEST");
        var remembered = rememberedContainerRevisions(shell, sourceId, fingerprint);
        if (remembered.isEmpty() || (revision != null && !remembered.contains(revision))) {
            throw new ActionRefusal("NOT_PRIVATELY_OBSERVED");
        }
        IsoGridSquare square = shell.getCell().getGridSquare(x, y, z);
        if (square == null || square.getCell() != shell.getCell()) throw new ActionRefusal("NOT_LOADED");
        String token = sourceId.substring(2);
        for (int index = 0; index < square.getObjects().size(); index++) {
            IsoObject object = square.getObjects().get(index);
            if (object == null || !token.equals(object.getModData().rawget(SOURCE_TOKEN))) continue;
            Source physical = objectFluidSource(new Snapshot(Math.floorDiv(x, CHUNK_SIZE),
                Math.floorDiv(y, CHUNK_SIZE)), square, object);
            if (!fingerprint.equals(physical.fingerprint)) throw new ActionRefusal("FINGERPRINT_CHANGED");
            if (revision != null && !revision.equals(physical.revision)) throw new ActionRefusal("REVISION_CHANGED");
            var fluid = object.getPrimaryFluid();
            if (object.isTaintedWater() || fluid != null && fluid.isPoisonous()
                    || object.getFluidAmount() > 0 && !object.hasWater()
                    || revision != null && object.getFluidAmount() <= 0) throw new ActionRefusal("NO_CLEAN_WATER");
            if (object instanceof IsoThumpable locked && locked.isLockedToCharacter(shell)
                    || GameClient.client && !zombie.iso.areas.SafeHouse.isSafehouseAllowInteract(square, shell)) {
                throw new ActionRefusal("ACCESS_REFUSED");
            }
            return object;
        }
        throw new ActionRefusal("SOURCE_MISSING");
    }

    private static boolean refillWithinReach(IsoPlayer shell, IsoGridSquare square) {
        IsoGridSquare here = shell == null ? null : shell.getCurrentSquare();
        return here != null && square != null && square.getCell() == shell.getCell()
            && shell.getCell().getGridSquare(square.getX(), square.getY(), square.getZ()) == square
            && square.getZ() == (int) Math.floor(shell.getZ())
            && Math.abs(shell.getX() - (square.getX() + 0.5f)) <= 1.6f
            && Math.abs(shell.getY() - (square.getY() + 0.5f)) <= 1.6f && here.canReachTo(square);
    }

    public static synchronized String plumbTarget(IsoPlayer shell, String sourceId,
            String fingerprint, String revision, int x, int y, int z) {
        try {
            if (revision == null || revision.isBlank()) return "BAD_PLUMB_REQUEST";
            IsoObject object = plumbFixture(shell, sourceId, fingerprint, revision, x, y, z, false);
            IsoGridSquare target = interactionSquare(shell, object.getSquare());
            return target == null ? "NO_INTERACTION_POINT"
                : "READY:" + target.getX() + ":" + target.getY() + ":" + target.getZ();
        } catch (ActionRefusal refusal) { return refusal.code; }
        catch (Throwable unavailable) { SAOAgent.log("world plumb target threw: " + unavailable); return "FAILED"; }
    }

    public static synchronized Object plumbObject(IsoPlayer shell, String sourceId,
            String fingerprint, String revision, int x, int y, int z) {
        try {
            if (revision == null || revision.isBlank()) return null;
            IsoObject object = plumbFixture(shell, sourceId, fingerprint, revision, x, y, z, false);
            return refillWithinReach(shell, object.getSquare()) ? object : null;
        } catch (Throwable unavailable) { return null; }
    }

    /** Connection changes the revision; exact identity and body custody persist. */
    public static synchronized boolean plumbValid(IsoPlayer shell, IsoObject object,
            String sourceId, String fingerprint, int x, int y, int z, boolean completedConnection) {
        try {
            return plumbFixture(shell, sourceId, fingerprint, null, x, y, z, completedConnection) == object
                && refillWithinReach(shell, object.getSquare());
        } catch (Throwable unavailable) { return false; }
    }

    private static IsoObject plumbFixture(IsoPlayer shell, String sourceId, String fingerprint,
            String revision, int x, int y, int z, boolean completedConnection) throws ActionRefusal {
        if (!inspectionActor(shell) || sourceId == null || !sourceId.startsWith("F:")
                || sourceId.length() <= 2 || fingerprint == null) throw new ActionRefusal("BAD_PLUMB_REQUEST");
        var remembered = rememberedContainerRevisions(shell, sourceId, fingerprint);
        if (remembered.isEmpty() || revision != null && !remembered.contains(revision)) {
            throw new ActionRefusal("NOT_PRIVATELY_OBSERVED");
        }
        IsoGridSquare square = shell.getCell().getGridSquare(x, y, z);
        if (square == null || square.getCell() != shell.getCell()) throw new ActionRefusal("NOT_LOADED");
        String token = sourceId.substring(2);
        for (int index = 0; index < square.getObjects().size(); index++) {
            IsoObject object = square.getObjects().get(index);
            if (object == null || object.getSquare() != square
                    || !token.equals(object.getModData().rawget(SOURCE_TOKEN))) continue;
            Source physical = objectFluidSource(new Snapshot(Math.floorDiv(x, CHUNK_SIZE), Math.floorDiv(y, CHUNK_SIZE)), square, object);
            if (!fingerprint.equals(physical.fingerprint)) throw new ActionRefusal("FINGERPRINT_CHANGED");
            if (revision != null && !revision.equals(physical.revision)) throw new ActionRefusal("REVISION_CHANGED");
            if (object instanceof IsoThumpable locked && locked.isLockedToCharacter(shell)
                    || GameClient.client && !zombie.iso.areas.SafeHouse.isSafehouseAllowInteract(square, shell)) {
                throw new ActionRefusal("ACCESS_REFUSED");
            }
            if (completedConnection ? !object.getUsesExternalWaterSource()
                    || !Boolean.FALSE.equals(object.getModData().rawget("canBeWaterPiped")) : !plumbingEligible(object)) {
                throw new ActionRefusal("PLUMBING_UNAVAILABLE");
            }
            return object;
        }
        throw new ActionRefusal("SOURCE_MISSING");
    }

    private static boolean waterPipedSprite(IsoObject object) {
        return object.getProperties() != null
            && object.getProperties().has(zombie.iso.SpriteDetails.IsoFlagType.waterPiped);
    }

    /** Local observable affordance only; supplier and mains truth belong to admission. */
    private static String plumbingState(IsoObject object) {
        if (object.getUsesExternalWaterSource()) {
            Object marker = object.getModData().rawget("canBeWaterPiped");
            return marker instanceof Boolean || waterPipedSprite(object) || object.getFluidCapacity() > 0
                ? "connected" : "";
        }
        IsoGridSquare square = object.getSquare();
        return square != null && square.isInARoom()
            && (Boolean.TRUE.equals(object.getModData().rawget("canBeWaterPiped")) || waterPipedSprite(object))
            ? "unconnected" : "";
    }

    /** Installed ISWorldObjectContextMenuLogic.fetch's two plumbing branches. */
    private static boolean plumbingEligible(IsoObject object) {
        IsoGridSquare square = object.getSquare();
        if (square == null || !square.isInARoom() || object.getUsesExternalWaterSource()) return false;
        boolean marked = Boolean.TRUE.equals(object.getModData().rawget("canBeWaterPiped"));
        boolean pipedSprite = waterPipedSprite(object);
        if (!marked && !pipedSprite) return false;
        if (object.FindExternalWaterSource() != null) return true;
        double days = zombie.GameTime.getInstance().getWorldAgeHours() / 24.0
            + (zombie.SandboxOptions.instance.getTimeSinceApo() - 1) * 30;
        return pipedSprite && marked && square.getRoom() != null
            && days < zombie.SandboxOptions.instance.waterShutModifier.getValue();
    }

    /** Personal generator identity; reached inspection alone supplies machine state. */
    public static synchronized String generatorCandidates(SAOIsoPlayerShell shell) {
        if (SAOConceptObservation.actor(shell) == null || transactionActive) return "";
        var eye = shell.getCurrentSquare();
        Snapshot snapshot = new Snapshot(Math.floorDiv(eye.getX(), CHUNK_SIZE), Math.floorDiv(eye.getY(), CHUNK_SIZE));
        snapshot.mode = "visible-generator";
        int count = 0;
        for (int distance = 0; distance <= INSPECTION_RANGE && count < 32; distance++) {
            for (int dy = -distance; dy <= distance && count < 32; dy++) for (int dx = -distance; dx <= distance && count < 32; dx++) {
                if (Math.max(Math.abs(dx), Math.abs(dy)) != distance) continue;
                var square = shell.getCell().getGridSquare(eye.getX() + dx, eye.getY() + dy, eye.getZ());
                if (!SAOPerceptionScanner.canSeeWorldSquareNow(shell, square, INSPECTION_RANGE)) continue;
                for (int index = 0; index < square.getObjects().size() && count < 32; index++) {
                    var object = square.getObjects().get(index);
                    if (!(object instanceof IsoGenerator generator) || generator.getSquare() != square) continue;
                    Source source = generatorSource(snapshot, generator, utilityReached(shell, square));
                    rememberUtility(shell, object, source); snapshot.add(source); count++;
                }
            }
        }
        snapshot.finish(); return encode(snapshot);
    }

    public static synchronized String generatorTarget(SAOIsoPlayerShell shell, String id, String fingerprint,
            String revision, int x, int y, int z, String operation) {
        try {
            if (revision == null || revision.isBlank()) return "BAD_GENERATOR_REQUEST";
            if (!generatorOperation(operation)) return "BAD_GENERATOR_OPERATION";
            var generator = generatorIdentityFixture(shell, id, fingerprint, revision, x, y, z);
            var square = interactionSquare(shell, generator.getSquare());
            return square == null ? "NO_INTERACTION_POINT" : "READY:" + square.getX() + ":" + square.getY() + ":" + square.getZ();
        } catch (ActionRefusal refusal) { return refusal.code; }
        catch (Throwable unavailable) { SAOAgent.log("generator target threw: " + unavailable); return "FAILED"; }
    }

    public static synchronized Object generatorObject(SAOIsoPlayerShell shell, String id, String fingerprint,
            String revision, int x, int y, int z, String operation) {
        try {
            if (revision == null || revision.isBlank()) return null;
            var generator = "inspect".equals(operation)
                ? generatorIdentityFixture(shell, id, fingerprint, revision, x, y, z)
                : generatorFixture(shell, id, fingerprint, revision, x, y, z, operation);
            return "verify-power".equals(operation) || utilityReached(shell, generator.getSquare()) ? generator : null;
        } catch (ActionRefusal refusal) { return null; }
        catch (Throwable unavailable) { SAOAgent.log("generator object threw: " + unavailable); return null; }
    }

    public static synchronized boolean generatorValid(SAOIsoPlayerShell shell, IsoGenerator generator,
            String id, String fingerprint, int x, int y, int z, String operation) {
        try {
            return generatorFixture(shell, id, fingerprint, null, x, y, z, operation) == generator
                && ("verify-power".equals(operation) || utilityReached(shell, generator.getSquare()));
        } catch (ActionRefusal refusal) { return false; }
        catch (Throwable unavailable) { SAOAgent.log("generator valid threw: " + unavailable); return false; }
    }

    private static IsoGenerator generatorFixture(SAOIsoPlayerShell shell, String id, String fingerprint,
            String revision, int x, int y, int z, String operation) throws ActionRefusal {
        var generator = generatorIdentityFixture(shell,id,fingerprint,revision,x,y,z);
        var binding = utilityBinding(shell, id, fingerprint, "J:");
        if (!generatorOperation(operation)) throw new ActionRefusal("BAD_GENERATOR_OPERATION");
        var square = shell.getCell().getGridSquare(x, y, z);
        boolean inspected = revision == null || Boolean.TRUE.equals(binding.revisions.get(revision));
        Source physical = generatorSource(new Snapshot(Math.floorDiv(x, CHUNK_SIZE), Math.floorDiv(y, CHUNK_SIZE)), generator, inspected);
        if (!fingerprint.equals(physical.fingerprint)) throw new ActionRefusal("FINGERPRINT_CHANGED");
        if (revision != null && !operation.equals("verify-power") && !revision.equals(physical.revision)) throw new ActionRefusal("REVISION_CHANGED");
        if (!operation.equals("inspect") && (revision == null ? !binding.revisions.containsValue(Boolean.TRUE)
                : !Boolean.TRUE.equals(binding.revisions.get(revision)))) throw new ActionRefusal("INSPECTION_REQUIRED");
        if (GameClient.client && !zombie.iso.areas.SafeHouse.isSafehouseAllowInteract(square, shell)) throw new ActionRefusal("ACCESS_REFUSED");
        boolean knowledge = shell.getPerkLevel(zombie.characters.skills.PerkFactory.Perks.Electricity) >= 3
            || shell.isRecipeActuallyKnown("Generator");
        if ((operation.equals("repair") || operation.equals("connect")) && !knowledge) throw new ActionRefusal("GENERATOR_KNOWLEDGE_REQUIRED");
        boolean ready = switch (operation) {
            case "inspect" -> true;
            case "repair" -> !generator.isActivated() && generator.getCondition() < 100;
            case "fuel" -> !generator.isActivated() && generator.getFuel() < generator.getMaxFuel();
            case "connect" -> !generator.isActivated() && !generator.isConnected();
            case "activate" -> !generator.isActivated() && generator.isConnected() && generator.getFuel() > 0
                && generator.getCondition() > 0 && square.isOutside();
            case "verify-power" -> generator.isActivated() && generator.isConnected() && generator.getFuel() > 0
                && generator.getCondition() > 0 && square.isOutside();
            default -> false;
        };
        if (!ready) throw new ActionRefusal("GENERATOR_STAGE_UNAVAILABLE");
        return generator;
    }

    /** Remembered identity admits travel and reached reinspection, never physical stage effects. */
    private static IsoGenerator generatorIdentityFixture(SAOIsoPlayerShell shell,String id,String fingerprint,
            String revision,int x,int y,int z) throws ActionRefusal {
        var binding=utilityBinding(shell,id,fingerprint,"J:");
        if (revision!=null && (revision.isBlank() || !binding.revisions.containsKey(revision))) throw new ActionRefusal("NOT_PRIVATELY_OBSERVED");
        var square=shell.getCell().getGridSquare(x,y,z);var object=binding.object.get();
        if (!(object instanceof IsoGenerator generator) || square==null || binding.square.get()!=square
                || object.getSquare()!=square || !square.getObjects().contains(object)
                || !id.substring(2).equals(object.getModData().rawget(SOURCE_TOKEN))) throw new ActionRefusal("SOURCE_CHANGED");
        Source identity=utilitySource(new Snapshot(Math.floorDiv(x,CHUNK_SIZE),Math.floorDiv(y,CHUNK_SIZE)),object,"J:","generator");
        if (!fingerprint.equals(identity.fingerprint)) throw new ActionRefusal("FINGERPRINT_CHANGED");
        if (GameClient.client && !zombie.iso.areas.SafeHouse.isSafehouseAllowInteract(square,shell)) throw new ActionRefusal("ACCESS_REFUSED");
        return generator;
    }

    private static boolean generatorOperation(String operation) {
        return "inspect".equals(operation) || "repair".equals(operation) || "fuel".equals(operation)
            || "connect".equals(operation) || "activate".equals(operation) || "verify-power".equals(operation);
    }

    private static boolean utilityReached(SAOIsoPlayerShell shell, IsoGridSquare square) {
        return refillWithinReach(shell, square) && Math.pow(shell.getX() - square.getX() - .5f, 2)
            + Math.pow(shell.getY() - square.getY() - .5f, 2) < 4
            && SAOPerceptionScanner.canSeeWorldSquareNow(shell, square, INSPECTION_RANGE);
    }

    public static synchronized String generatorConsumer(SAOIsoPlayerShell shell, IsoObject object) {
        if (SAOConceptObservation.actor(shell) == null || object == null || object.getSquare() == null
                || !utilityReached(shell, object.getSquare()) || object.getCell() != shell.getCell()
                || !object.getSquare().getObjects().contains(object) || !object.couldBePoweredByGenerator()) return "";
        var square = object.getSquare();
        Snapshot snapshot = new Snapshot(Math.floorDiv(square.getX(), CHUNK_SIZE), Math.floorDiv(square.getY(), CHUNK_SIZE));
        snapshot.mode = "reached-power-consumer";
        Source source = powerConsumerSource(snapshot, object); rememberUtility(shell, object, source);
        snapshot.add(source); snapshot.finish(); return encode(snapshot);
    }

    public static synchronized boolean generatorConsumerPowered(SAOIsoPlayerShell shell, IsoGenerator generator,
            String id, String fingerprint, int x, int y, int z) {
        try {
            var consumerBinding = utilityBinding(shell, id, fingerprint, "E:");
            var consumer = consumerBinding.object.get(); var square = shell.getCell().getGridSquare(x, y, z);
            if (consumer == null || square == null || consumerBinding.square.get() != square || consumer.getSquare() != square
                || !square.getObjects().contains(consumer) || !utilityReached(shell, square)
                || !id.substring(2).equals(consumer.getModData().rawget(SOURCE_TOKEN))) return false;
            Source current = powerConsumerSource(new Snapshot(Math.floorDiv(x, CHUNK_SIZE), Math.floorDiv(y, CHUNK_SIZE)), consumer);
            if (!fingerprint.equals(current.fingerprint) || generator == null || generator.getSquare() == null) return false;
            var genSquare = generator.getSquare();
            String token = (String) generator.getModData().rawget(SOURCE_TOKEN);
            Source gen = generatorSource(new Snapshot(Math.floorDiv(genSquare.getX(), CHUNK_SIZE), Math.floorDiv(genSquare.getY(), CHUNK_SIZE)), generator, true);
            var genBinding = utilityBinding(shell, "J:" + token, gen.fingerprint, "J:");
            return genBinding.object.get() == generator && genBinding.square.get() == genSquare
                && generator.getCell() == shell.getCell() && shell.getCell().getGridSquare(genSquare.getX(), genSquare.getY(), genSquare.getZ()) == genSquare
                && genSquare.getObjects().contains(generator) && generator.isConnected() && generator.isActivated()
                && generator.getFuel() > 0 && generator.getCondition() > 0 && genSquare.isOutside()
                && IsoGenerator.isPoweringSquare(genSquare.getX(), genSquare.getY(), genSquare.getZ(), x, y, z)
                && square.haveElectricity() && current.powered == Boolean.TRUE;
        } catch (ActionRefusal refusal) { return false; }
        catch (Throwable unavailable) { SAOAgent.log("generator consumer power threw: " + unavailable); return false; }
    }

    public static synchronized String generatorConsumerTarget(SAOIsoPlayerShell shell, String id, String fingerprint,
            String revision, int x, int y, int z) {
        try {
            IsoObject object = generatorConsumerFixture(shell, id, fingerprint, revision, x, y, z);
            var square = interactionSquare(shell, object.getSquare());
            return square == null ? "NO_INTERACTION_POINT" : "READY:" + square.getX() + ":" + square.getY() + ":" + square.getZ();
        } catch (ActionRefusal refusal) { return refusal.code; }
        catch (Throwable unavailable) { SAOAgent.log("generator consumer target threw: " + unavailable); return "FAILED"; }
    }

    public static synchronized Object generatorConsumerObject(SAOIsoPlayerShell shell, String id, String fingerprint,
            String revision, int x, int y, int z) {
        try {
            var object = generatorConsumerFixture(shell, id, fingerprint, revision, x, y, z);
            return utilityReached(shell, object.getSquare()) ? object : null;
        } catch (ActionRefusal refusal) { return null; }
        catch (Throwable unavailable) { SAOAgent.log("generator consumer object threw: " + unavailable); return null; }
    }

    private static IsoObject generatorConsumerFixture(SAOIsoPlayerShell shell, String id, String fingerprint,
            String revision, int x, int y, int z) throws ActionRefusal {
        var binding = utilityBinding(shell, id, fingerprint, "E:");
        if (revision == null || !binding.revisions.containsKey(revision)) throw new ActionRefusal("NOT_PRIVATELY_OBSERVED");
        var square = shell.getCell().getGridSquare(x,y,z); var object = binding.object.get();
        if (square == null || object == null || binding.square.get() != square || object.getSquare() != square
                || !square.getObjects().contains(object) || !id.substring(2).equals(object.getModData().rawget(SOURCE_TOKEN))) throw new ActionRefusal("SOURCE_CHANGED");
        var source = powerConsumerSource(new Snapshot(Math.floorDiv(x,CHUNK_SIZE),Math.floorDiv(y,CHUNK_SIZE)),object);
        if (!fingerprint.equals(source.fingerprint)) throw new ActionRefusal("FINGERPRINT_CHANGED");
        // Power may change during the owned generator sequence. Identity and the exact acquired revision remain binding.
        if (!object.couldBePoweredByGenerator() || GameClient.client && !zombie.iso.areas.SafeHouse.isSafehouseAllowInteract(square,shell)) throw new ActionRefusal("ACCESS_REFUSED");
        return object;
    }

    private static UtilityBinding utilityBinding(SAOIsoPlayerShell shell, String id, String fingerprint, String prefix) throws ActionRefusal {
        String actor = SAOConceptObservation.actor(shell);
        var bindings = UTILITY_BINDINGS.get(shell); var binding = bindings == null ? null : bindings.get(id);
        if (actor == null || id == null || !id.startsWith(prefix) || id.length() <= 2 || fingerprint == null) throw new ActionRefusal("NOT_PRIVATELY_OBSERVED");
        if (binding == null || binding.object.get() == null || binding.square.get() == null) {
            binding = restoreUtilityBinding(shell,actor,id,fingerprint,prefix);
        }
        if (binding == null || !actor.equals(binding.actor) || !fingerprint.equals(binding.fingerprint)) throw new ActionRefusal("NOT_PRIVATELY_OBSERVED");
        return binding;
    }

    private static UtilityBinding restoreUtilityBinding(SAOIsoPlayerShell shell,String actor,String id,String fingerprint,String prefix) {
        var sao=table(zombie.Lua.LuaManager.env.rawget("SAO"));var perception=sao==null?null:table(sao.rawget("Perception"));
        var beliefs=perception==null?null:table(perception.rawget("beliefs"));var mind=beliefs==null?null:table(beliefs.rawget(actor));
        var known=mind==null?null:table(mind.rawget("known"));if(known==null)return null;
        var places=known.iterator();
        while(places.advance()) {
            var place=table(places.getValue());var facts=place==null?null:table(place.rawget("sourceFacts"));var fact=facts==null?null:table(facts.rawget(id));
            if(fact==null || !fingerprint.equals(fact.rawget("fingerprint")) || !(fact.rawget("revision") instanceof String revision) || revision.isBlank()
                    || !(prefix.equals("J:")?"generator":"power-consumer").equals(fact.rawget("kind"))
                    || fact.rawget("actorId")!=null && !actor.equals(fact.rawget("actorId"))
                    || !id.equals(fact.rawget("sourceId")) && !id.equals(fact.rawget("id")))continue;
            Object rx=fact.rawget("x"),ry=fact.rawget("y"),rz=fact.rawget("z");
            if(!(rx instanceof Number nx)||!(ry instanceof Number ny)||!(rz instanceof Number nz))continue;
            double x=nx.doubleValue(),y=ny.doubleValue(),z=nz.doubleValue();
            if(!Double.isFinite(x)||!Double.isFinite(y)||!Double.isFinite(z)||x!=Math.rint(x)||y!=Math.rint(y)||z!=Math.rint(z)
                    ||Math.abs(x)>Integer.MAX_VALUE||Math.abs(y)>Integer.MAX_VALUE||Math.abs(z)>Integer.MAX_VALUE)continue;
            var square=shell.getCell().getGridSquare((int)x,(int)y,(int)z);if(square==null || square.getCell()!=shell.getCell())continue;
            for(int index=0;index<square.getObjects().size();index++) {
                var object=square.getObjects().get(index);
                if(object==null||object.getSquare()!=square||!id.substring(2).equals(object.getModData().rawget(SOURCE_TOKEN))
                        || (prefix.equals("J:")?!(object instanceof IsoGenerator):!object.couldBePoweredByGenerator()))continue;
                var identity=utilitySource(new Snapshot(Math.floorDiv((int)x,CHUNK_SIZE),Math.floorDiv((int)y,CHUNK_SIZE)),object,prefix,prefix.equals("J:")?"generator":"power-consumer");
                if(!fingerprint.equals(identity.fingerprint))continue;
                var binding=new UtilityBinding(actor,object,fingerprint);
                // Saved inspection is historical person knowledge; reacquire current inspection before any operation.
                binding.revisions.put(revision,Boolean.FALSE);
                var bindings=UTILITY_BINDINGS.computeIfAbsent(shell,ignored->new LinkedHashMap<>());bindings.put(id,binding);
                while(bindings.size()>MAX_INSPECTION_OPTIONS)bindings.remove(bindings.keySet().iterator().next());
                return binding;
            }
        }
        return null;
    }

    private static void rememberUtility(SAOIsoPlayerShell shell, IsoObject object, Source source) {
        var bindings = UTILITY_BINDINGS.computeIfAbsent(shell, ignored -> new LinkedHashMap<>());
        var binding = bindings.get(source.id);
        if (binding == null || binding.object.get() != object || !binding.fingerprint.equals(source.fingerprint)
                || !binding.actor.equals(SAOConceptObservation.actor(shell))) {
            binding = new UtilityBinding(SAOConceptObservation.actor(shell), object, source.fingerprint); bindings.put(source.id, binding);
        }
        binding.revisions.put(source.revision, Boolean.TRUE.equals(source.inspected));
        while (binding.revisions.size() > 16) binding.revisions.remove(binding.revisions.keySet().iterator().next());
        while (bindings.size() > MAX_INSPECTION_OPTIONS) bindings.remove(bindings.keySet().iterator().next());
    }

    private static final class UtilityBinding {
        final String actor, fingerprint;
        final java.lang.ref.WeakReference<IsoObject> object;
        final java.lang.ref.WeakReference<IsoGridSquare> square;
        final LinkedHashMap<String, Boolean> revisions = new LinkedHashMap<>();
        UtilityBinding(String actor, IsoObject object, String fingerprint) {
            this.actor = actor; this.fingerprint = fingerprint;
            this.object = new java.lang.ref.WeakReference<>(object); this.square = new java.lang.ref.WeakReference<>(object.getSquare());
        }
    }

    private static Source utilitySource(Snapshot snapshot, IsoObject object, String prefix, String kind) {
        var square = object.getSquare(); long building = buildingId(square); String token = sourceToken(snapshot, object);
        String identity = object.getClass().getName() + "|" + value(object.getSpriteName()) + "|" + kind + "|" + building
            + "|" + square.getX() + "|" + square.getY() + "|" + square.getZ() + "|" + token;
        return new Source(prefix + token, digest(identity), kind, square.getX(), square.getY(), square.getZ(), building, true);
    }

    private static Source generatorSource(Snapshot snapshot, IsoGenerator generator, boolean inspected) {
        Source source = utilitySource(snapshot, generator, "J:", "generator"); source.inspected = inspected;
        if (inspected) {
            source.generatorCondition = generator.getCondition(); source.generatorFuel = generator.getFuel(); source.generatorMaxFuel = generator.getMaxFuel();
            source.connected = generator.isConnected(); source.active = generator.isActivated(); source.outside = generator.getSquare().isOutside();
        }
        source.finish(); return source;
    }

    private static Source powerConsumerSource(Snapshot snapshot, IsoObject object) {
        Source source = utilitySource(snapshot, object, "E:", "power-consumer"); source.inspected = true;
        // The native static query is fresh; checkObjectPowered caches for one IngameState tick.
        source.powered = ItemContainer.isObjectPowered(object, true); source.finish(); return source;
    }

    /** Visible current-floor sites. Recipe-specific clearance remains native build authority. */
    public static synchronized String collectorSites(SAOIsoPlayerShell shell) {
        String actor = SAOConceptObservation.actor(shell);
        if (actor == null || transactionActive) return "";
        var remembered = COLLECTOR_SITES.computeIfAbsent(shell, ignored -> new LinkedHashMap<>());
        var eye = shell.getCurrentSquare();
        StringBuilder out = new StringBuilder();
        int count = 0;
        for (int distance = 0; distance <= INSPECTION_RANGE && count < 32; distance++) {
            for (int dy = -distance; dy <= distance && count < 32; dy++) {
                for (int dx = -distance; dx <= distance && count < 32; dx++) {
                    if (Math.max(Math.abs(dx), Math.abs(dy)) != distance) continue;
                    var square = shell.getCell().getGridSquare(eye.getX() + dx, eye.getY() + dy, eye.getZ());
                    if (!collectorSiteUsable(square)
                            || !SAOPerceptionScanner.canSeeWorldSquareNow(shell, square, INSPECTION_RANGE)) continue;
                    String key = square.getX() + ":" + square.getY() + ":" + square.getZ();
                    var binding = remembered.get(key);
                    if (binding == null || !binding.matches(actor, square)) {
                        binding = new CollectorSiteBinding(actor, square);
                        remembered.put(key, binding);
                    }
                    if (out.length() > 0) out.append('|');
                    out.append(square.getX()).append(',').append(square.getY()).append(',')
                        .append(square.getZ()).append(',').append(binding.revision.replace('|', '_').replace(',', '_'));
                    count++;
                }
            }
        }
        while (remembered.size() > MAX_INSPECTION_OPTIONS)
            remembered.remove(remembered.keySet().iterator().next());
        return out.toString();
    }

    public static synchronized IsoGridSquare collectorPlacementSquare(SAOIsoPlayerShell shell,
            int x, int y, int z, String revision) {
        String actor = SAOConceptObservation.actor(shell);
        var remembered = COLLECTOR_SITES.get(shell);
        var binding = remembered == null ? null : remembered.get(x + ":" + y + ":" + z);
        var square = actor == null ? null : shell.getCell().getGridSquare(x, y, z);
        return binding != null && binding.revision.equals(revision)
            && binding.matches(actor, square) && collectorSiteUsable(square)
            && SAOPerceptionScanner.canSeeWorldSquareNow(shell, square, INSPECTION_RANGE)
            && refillWithinReach(shell, square) ? square : null;
    }

    /** Physical validation; the native action owner proves this object's creation. */
    public static synchronized boolean collectorCreated(SAOIsoPlayerShell shell, IsoThumpable collector,
            String entityId, int x, int y, int z) {
        if (SAOConceptObservation.actor(shell) == null || collector == null || entityId == null
                || !(entityId.equals("Base.RainCollector") || entityId.equals("Base.RainCollectorRound")
                    || entityId.equals("Base.RainCollector_Tarp") || entityId.equals("Base.RainCollectorRound_Tarp"))) return false;
        var square = shell.getCell().getGridSquare(x, y, z);
        var script = collector.getEntityScript();
        var fluid = collector.getFluidContainer();
        return square != null && square.getCell() == shell.getCell() && collector.getCell() == shell.getCell()
            && collector.getSquare() == square && square.getObjects().contains(collector)
            && collector.getObjectIndex() >= 0 && !collector.getUsesExternalWaterSource()
            && script != null && entityId.equals(script.getFullName())
            && fluid != null && fluid.getGameEntity() == collector && fluid.getCapacity() > 0
            && fluid.getRainCatcher() > 0 && collector.getFluidCapacity() == fluid.getCapacity();
    }

    public static synchronized String collectorSource(SAOIsoPlayerShell shell, IsoThumpable collector,
            String entityId, int x, int y, int z) {
        if (!collectorCreated(shell, collector, entityId, x, y, z)) return "";
        Source source = objectFluidSource(new Snapshot(Math.floorDiv(x, CHUNK_SIZE), Math.floorDiv(y, CHUNK_SIZE)),
            collector.getSquare(), collector);
        return source.id + "|" + source.fingerprint;
    }

    public static synchronized boolean collectorFeedsFixture(SAOIsoPlayerShell shell, IsoThumpable collector,
            String sourceId, String fingerprint, int x, int y, int z) {
        if (SAOConceptObservation.actor(shell) == null || collector == null || collector.getSquare() == null
                || sourceId == null || !sourceId.startsWith("F:") || sourceId.length() <= 2 || fingerprint == null
                || rememberedContainerRevisions(shell, sourceId, fingerprint).isEmpty()) return false;
        var roof = collector.getSquare();
        var script = collector.getEntityScript();
        if (script == null || !collectorCreated(shell, collector, script.getFullName(), roof.getX(), roof.getY(), roof.getZ())) return false;
        var square = shell.getCell().getGridSquare(x, y, z);
        if (square == null || square.getCell() != shell.getCell()) return false;
        for (int index = 0; index < square.getObjects().size(); index++) {
            var fixture = square.getObjects().get(index);
            if (fixture == null || fixture.getSquare() != square
                    || !sourceId.substring(2).equals(fixture.getModData().rawget(SOURCE_TOKEN))) continue;
            Source source = objectFluidSource(new Snapshot(Math.floorDiv(x, CHUNK_SIZE), Math.floorDiv(y, CHUNK_SIZE)), square, fixture);
            if (!source.fingerprint.equals(fingerprint)
                    || fixture instanceof IsoThumpable locked && locked.isLockedToCharacter(shell)
                    || GameClient.client && !zombie.iso.areas.SafeHouse.isSafehouseAllowInteract(square, shell)) return false;
            return fixture.FindExternalWaterSource() == collector;
        }
        return false;
    }

    private static boolean collectorSiteUsable(IsoGridSquare square) {
        return square != null && square.isOutside() && square.isSolidFloor()
            && square.isFree(false) && !square.HasStairs() && !square.HasTree()
            && square.getMovingObjects().isEmpty() && !square.isVehicleIntersecting() && !square.haveFire();
    }

    private static final class CollectorSiteBinding {
        final String actor, revision = UUID.randomUUID().toString();
        final java.lang.ref.WeakReference<IsoGridSquare> square;
        final ArrayList<java.lang.ref.WeakReference<IsoObject>> objects = new ArrayList<>();
        final ArrayList<String> sprites = new ArrayList<>();
        CollectorSiteBinding(String actor, IsoGridSquare square) {
            this.actor = actor; this.square = new java.lang.ref.WeakReference<>(square);
            for (int index = 0; index < square.getObjects().size(); index++) {
                var object = square.getObjects().get(index);
                objects.add(new java.lang.ref.WeakReference<>(object));
                sprites.add(object.getSpriteName());
            }
        }
        boolean matches(String actor, IsoGridSquare square) {
            if (!this.actor.equals(actor) || this.square.get() != square || square == null
                    || objects.size() != square.getObjects().size()) return false;
            for (int index = 0; index < objects.size(); index++) {
                var object = square.getObjects().get(index);
                if (objects.get(index).get() != object
                        || !java.util.Objects.equals(sprites.get(index), object.getSpriteName())) return false;
            }
            return true;
        }
    }

    /** Bind the exact source only after the actor has reached its interaction point. */
    public static synchronized String bindAction(IsoPlayer shell, String sourceId,
            String fingerprint, String revision, int itemId, String itemType,
            int expectedX, int expectedY, int expectedZ) {
        try {
            Located located = locate(shell, sourceId, fingerprint, revision,
                itemId, itemType, expectedX, expectedY, expectedZ);
            boolean accessible = located.worldItem != null
                ? squareWithinReach(shell, located.square)
                : SAONeeds.containerAccessibleNow(shell,
                    located.permissionContainer);
            if (!accessible) return "ACCESS_REFUSED";
            ACTIONS.put(shell, new ActionBinding(located));
            return "BOUND:" + located.square.getX() + ":"
                + located.square.getY() + ":" + located.square.getZ();
        } catch (ActionRefusal refusal) {
            return refusal.code;
        } catch (Throwable throwable) {
            SAOAgent.log("world source bind threw: " + throwable);
            return "FAILED";
        }
    }

    public static synchronized Object actionItem(IsoPlayer shell) {
        ActionBinding binding = ACTIONS.get(shell);
        return binding == null ? null : binding.item;
    }

    public static synchronized Object actionSourceContainer(IsoPlayer shell) {
        ActionBinding binding = ACTIONS.get(shell);
        return binding == null ? null : binding.sourceContainer;
    }

    /** The item's actual holder at binding, including a carried nested bag. */
    public static synchronized Object actionOriginContainer(IsoPlayer shell) {
        ActionBinding binding = ACTIONS.get(shell);
        return binding == null ? null : binding.originContainer;
    }

    public static synchronized Object actionPermissionContainer(IsoPlayer shell) {
        ActionBinding binding = ACTIONS.get(shell);
        return binding == null ? null : binding.permissionContainer;
    }

    public static synchronized Object actionWorldItem(IsoPlayer shell) {
        ActionBinding binding = ACTIONS.get(shell);
        return binding == null ? null : binding.worldItem;
    }

    /** Find the exact transferred item in the body's native inventory. */
    public static synchronized Object carriedActionItem(IsoPlayer shell, int itemId,
            String itemType) {
        try {
            return findItem(shell == null ? null : shell.getInventory(), itemId,
                itemType, 0);
        } catch (Throwable throwable) {
            return null;
        }
    }

    public static synchronized String carriedTransferItem(IsoPlayer shell, int itemId,
            String itemType) {
        try {
            ItemContainer inventory = shell == null ? null : shell.getInventory();
            InventoryItem item = findItem(inventory, itemId, itemType, 0);
            return item == null || countItemId(inventory, itemId, 0) != 1
                ? "" : "T" + itemFields(ItemRow.of(item));
        } catch (Throwable throwable) {
            return "";
        }
    }

    /** Current absolute amount used to partition a reload-resumed native use. */
    public static synchronized float carriedActionMeasure(IsoPlayer shell,
            int itemId, String itemType, String category) {
        try {
            InventoryItem item = findItem(shell == null ? null : shell.getInventory(),
                itemId, itemType, 0);
            if (item == null) return -1.0f;
            return "water".equals(value(category))
                || "drink".equals(value(category))
                ? fluidAmount(item) : item.getCurrentUsesFloat();
        } catch (Throwable throwable) {
            return -1.0f;
        }
    }

    /** Snapshot the exact carried item and the body's native need before use. */
    public static synchronized boolean beginUse(IsoPlayer shell, int itemId,
            String itemType, String category, float durableBaseline) {
        try {
            InventoryItem item = findItem(shell == null ? null : shell.getInventory(),
                itemId, itemType, 0);
            if (item == null) return false;
            ActionBinding binding = ACTIONS.get(shell);
            if (binding == null || binding.item.getID() != itemId) {
                binding = new ActionBinding(item);
                ACTIONS.put(shell, binding);
            }
            binding.item = item;
            binding.category = value(category);
            binding.usesBefore = item.getUses();
            binding.currentUsesBefore = durableBaseline >= 0.0f
                ? durableBaseline : item.getCurrentUsesFloat();
            binding.amountBefore = durableBaseline >= 0.0f
                ? durableBaseline : fluidAmount(item);
            binding.hungerBefore = shell.getStats().get(CharacterStat.HUNGER);
            binding.thirstBefore = shell.getStats().get(CharacterStat.THIRST);
            binding.useStarted = true;
            binding.settled = false;
            return true;
        } catch (Throwable throwable) {
            SAOAgent.log("world source begin use threw: " + throwable);
            return false;
        }
    }

    /**
     * Verify what vanilla actually changed. Complete and stop both pass here:
     * a stopped drink may already have consumed fluid, while a stopped meal
     * may have applied its partial eat. No physical change means no result.
     */
    public static synchronized String finishUse(IsoPlayer shell, boolean completed) {
        try {
            ActionBinding binding = ACTIONS.get(shell);
            if (binding == null || !binding.useStarted || binding.settled) {
                return "NO_EFFECT:0:no-active-use";
            }
            binding.settled = true;
            InventoryItem carried = findItem(shell.getInventory(),
                binding.item.getID(), binding.item.getFullType(), 0);
            float amountAfter = carried == null ? 0.0f : fluidAmount(carried);
            float currentAfter = carried == null ? 0.0f
                : carried.getCurrentUsesFloat();
            float quantity;
            if ("water".equals(binding.category)
                    || "drink".equals(binding.category)) {
                quantity = Math.max(0.0f, binding.amountBefore - amountAfter);
            } else {
                quantity = Math.max(0.0f,
                    binding.currentUsesBefore - currentAfter);
            }
            if (carried == null && quantity <= 0.0001f) quantity = 1.0f;
            float hungerAfter = shell.getStats().get(CharacterStat.HUNGER);
            float thirstAfter = shell.getStats().get(CharacterStat.THIRST);
            boolean changed = quantity > 0.0001f
                || hungerAfter < binding.hungerBefore - 0.0001f
                || thirstAfter < binding.thirstBefore - 0.0001f;
            if (!changed) return "NO_EFFECT:0:native-use-made-no-change";
            return "APPLIED:" + (completed ? "completed" : "interrupted")
                + ":" + number(quantity) + ":"
                + (completed ? "native-complete" : "native-partial-stop");
        } catch (Throwable throwable) {
            SAOAgent.log("world source finish use threw: " + throwable);
            return "NO_EFFECT:0:verification-failed";
        }
    }

    public static synchronized void clearAction(IsoPlayer shell) {
        ACTIONS.remove(shell);
    }

    /** Locate a currently reachable native holder for use-time claim checks. */
    public static synchronized String transferPosition(IsoPlayer shell,
            ItemContainer container) {
        try {
            if (!SAONeeds.containerAccessibleNow(shell, container)) return "";
            IsoGridSquare square;
            if (container.isVehiclePart()) {
                square = container.getVehicle().getSquare();
            } else {
                IsoObject parent = container.getParent();
                square = parent == null ? null : parent.getSquare();
                if (square == null || !square.getObjects().contains(parent)) return "";
                boolean owns = false;
                for (int index = 0; index < parent.getContainerCount(); index++) {
                    if (parent.getContainerByIndex(index) == container) owns = true;
                }
                if (!owns) return "";
            }
            return square == null ? "" : "AT:" + square.getX() + ":"
                + square.getY() + ":" + square.getZ();
        } catch (Throwable unavailable) {
            return "";
        }
    }

    /** Inspect one reachable transfer while retaining complete chunk coverage. */
    public static synchronized String transferOffer(IsoPlayer shell,
            InventoryItem item, ItemContainer worldContainer, String operation) {
        if (transactionActive || shell == null || item == null
                || worldContainer == null
                || !("acquire".equals(operation) || "store".equals(operation))) {
            return "";
        }
        transactionActive = true;
        try {
            boolean storing = "store".equals(operation);
            if (!transferPermitted(shell, item, worldContainer, storing)) return "";
            IsoCell cell = shell.getCell();
            if (cell == null || cell != currentCell()) return "";
            IsoGridSquare square;
            IsoObject object = null;
            BaseVehicle vehicle = null;
            VehiclePart part = null;
            int containerIndex = -1;
            if (worldContainer.isVehiclePart()) {
                vehicle = worldContainer.getVehicle();
                part = worldContainer.getVehiclePart();
                if (vehicle == null || part == null || vehicle.getSqlId() < 0
                        || vehicle.isRemovedFromWorld()
                        || !cell.getVehicles().contains(vehicle)
                        || part.getItemContainer() != worldContainer) return "";
                square = vehicle.getSquare();
            } else {
                object = worldContainer.getParent();
                square = object == null ? null : object.getSquare();
                if (square == null || !square.getObjects().contains(object)) return "";
                for (int index = 0; index < object.getContainerCount(); index++) {
                    if (object.getContainerByIndex(index) == worldContainer) {
                        containerIndex = index;
                        break;
                    }
                }
                if (containerIndex < 0) return "";
            }
            if (square == null || square.getCell() != cell
                    || cell.getGridSquare(square.getX(), square.getY(), square.getZ())
                        != square) return "";
            int chunkX = Math.floorDiv(square.getX(), CHUNK_SIZE);
            int chunkY = Math.floorDiv(square.getY(), CHUNK_SIZE);
            IsoChunk chunk = cell.getChunk(chunkX, chunkY);
            if (chunk == null) return "";
            Snapshot snapshot = scan(chunk, false);
            String sourceId = vehicle == null
                ? "C:" + value((String) object.getModData().rawget(SOURCE_TOKEN))
                    + ":" + containerIndex
                : "V:" + vehicle.getSqlId() + ":" + part.getIndex();
            Source source = snapshot.byId.get(sourceId);
            if (source == null || !source.explored) return "";
            Located located = locate(shell, source.id, source.fingerprint,
                source.revision, item.getID(), item.getFullType(), source.x,
                source.y, source.z, storing ? ItemLocation.CARRIED : ItemLocation.SOURCE);
            if (located.item != item || located.permissionContainer != worldContainer
                    || !transferPermitted(shell, item, worldContainer, storing)) return "";
            if (snapshot.identitiesStamped) save(chunk);
            ItemRow row = ItemRow.of(item);
            return "T|operation=" + operation + "|source=" + field(source.id)
                + itemFields(row) + "\n" + encode(snapshot);
        } catch (Throwable throwable) {
            SAOAgent.log("world transfer offer refused: " + throwable);
            return "";
        } finally {
            transactionActive = false;
        }
    }

    public static synchronized String storeActionTarget(IsoPlayer shell,
            String sourceId, String fingerprint, String revision, int itemId,
            String itemType, int expectedX, int expectedY, int expectedZ) {
        try {
            Located located = locate(shell, sourceId, fingerprint, revision,
                itemId, itemType, expectedX, expectedY, expectedZ, ItemLocation.CARRIED);
            IsoGridSquare target = located.vehicle == null
                ? interactionSquare(shell, located.square)
                : vehicleInteractionSquare(located.vehicle, located.vehiclePart);
            if (target == null) return "NO_INTERACTION_POINT";
            return "READY:" + target.getX() + ":" + target.getY() + ":"
                + target.getZ() + ":" + located.square.getX() + ":"
                + located.square.getY() + ":" + located.square.getZ();
        } catch (ActionRefusal refusal) {
            return refusal.code;
        } catch (Throwable throwable) {
            SAOAgent.log("world store target threw: " + throwable);
            return "FAILED";
        }
    }

    public static synchronized String bindStoreAction(IsoPlayer shell,
            String sourceId, String fingerprint, String revision, int itemId,
            String itemType, int expectedX, int expectedY, int expectedZ) {
        try {
            Located located = locate(shell, sourceId, fingerprint, revision,
                itemId, itemType, expectedX, expectedY, expectedZ, ItemLocation.CARRIED);
            if (!transferPermitted(shell, located.item, located.permissionContainer,
                    true)) return "ACCESS_REFUSED";
            ACTIONS.put(shell, new ActionBinding(located));
            return "BOUND:" + located.square.getX() + ":"
                + located.square.getY() + ":" + located.square.getZ();
        } catch (ActionRefusal refusal) {
            return refusal.code;
        } catch (Throwable throwable) {
            SAOAgent.log("world store bind threw: " + throwable);
            return "FAILED";
        }
    }

    /** Holder evidence survives queue loss and never moves or recreates an item. */
    public static synchronized String storeTransferState(IsoPlayer shell,
            String sourceId, String fingerprint, int itemId, String itemType,
            int expectedX, int expectedY, int expectedZ) {
        try {
            Located located = locate(shell, sourceId, fingerprint, null, itemId,
                itemType, expectedX, expectedY, expectedZ, ItemLocation.CONTAINER);
            return transferHolderState(shell.getInventory(),
                located.permissionContainer, itemId, itemType);
        } catch (ActionRefusal refusal) {
            return "NOT_LOADED".equals(refusal.code)
                || ("SOURCE_MISSING".equals(refusal.code)
                    && sourceId != null && sourceId.startsWith("V:"))
                || "BAD_REQUEST".equals(refusal.code) ? "UNAVAILABLE" : "CONFLICT";
        } catch (Throwable throwable) {
            SAOAgent.log("world store state unreadable: " + throwable);
            return "UNAVAILABLE";
        }
    }

    private static String transferHolderState(ItemContainer carried,
            ItemContainer destination, int itemId, String itemType) {
        if (carried == null || destination == null || carried == destination) {
            return "CONFLICT";
        }
        int carriedCount = countItemId(carried, itemId, 0);
        int destinationCount = countItemId(destination, itemId, 0);
        InventoryItem atDestination = findItem(destination, itemId, itemType, 0);
        if (carriedCount == 0 && destinationCount == 1 && atDestination != null
                && atDestination.getContainer() == destination) return "TRANSFERRED";
        if (carriedCount == 1 && destinationCount == 0
                && findItem(carried, itemId, itemType, 0) != null) return "CARRIED";
        return "CONFLICT";
    }

    private static boolean transferPermitted(IsoPlayer shell, InventoryItem item,
            ItemContainer worldContainer, boolean storing) {
        if (shell == null || item == null || worldContainer == null
                || !worldContainer.isExplored()
                || worldContainer.getOutermostContainer() != worldContainer
                || worldContainer.isInCharacterInventory(shell)
                || !SAONeeds.containerAccessibleNow(shell, worldContainer)
                || item instanceof InventoryContainer || item.getIsCraftingConsumed()
                || "CandleLit".equals(item.getType())
                || "Lantern_HurricaneLit".equals(item.getType())) return false;
        ItemRow row = ItemRow.of(item);
        if (row.categories.isEmpty()) {
            return false;
        }
        ItemContainer inventory = shell.getInventory();
        ItemContainer holder = storing ? inventory : worldContainer;
        ItemContainer other = storing ? worldContainer : inventory;
        if (findItem(holder, item.getID(), item.getFullType(), 0) != item
                || countItemId(holder, item.getID(), 0) != 1
                || countItemId(other, item.getID(), 0) != 0) return false;
        ItemContainer origin = item.getContainer();
        ItemContainer destination = storing ? worldContainer : inventory;
        return origin != null && origin != destination && origin.contains(item)
            && (!storing || !item.isFavorite()) && origin.isRemoveItemAllowed(item)
            && destination.isItemAllowed(item) && !destination.isInside(item)
            && destination.hasRoomFor(shell, item);
    }

    private static int countItemId(ItemContainer container, int itemId, int depth) {
        if (container == null) return 0;
        if (depth > MAX_CONTAINER_DEPTH) {
            throw new IllegalStateException("native transfer nesting exceeds bound");
        }
        int count = 0;
        for (InventoryItem item : new ArrayList<>(container.getItems())) {
            if (item == null) continue;
            if (item.getID() == itemId) count++;
            if (item instanceof InventoryContainer nested) {
                count += countItemId(nested.getInventory(), itemId, depth + 1);
            }
        }
        return count;
    }

    /** Observe a chunk already owned by a live player map. Never rolls loot. */
    public static synchronized String observeLoadedChunk(int chunkX, int chunkY) {
        if (transactionActive) {
            return error("BUSY", "another source transaction is active", chunkX, chunkY);
        }
        transactionActive = true;
        try {
            IsoCell cell = currentCell();
            if (cell == null) {
                return error("NO_WORLD", "no current cell", chunkX, chunkY);
            }
            IsoChunk chunk = cell.getChunk(chunkX, chunkY);
            if (chunk == null) {
                return error("NOT_LOADED", "chunk is outside every active map", chunkX, chunkY);
            }
            Snapshot snapshot = scan(chunk, false);
            if (snapshot.identitiesStamped) {
                save(chunk);
            }
            snapshot.status = "OBSERVED";
            snapshot.mode = "loaded";
            return encode(snapshot);
        } catch (Throwable throwable) {
            SAOAgent.log("world sources: loaded observation failed at " + chunkX + ","
                + chunkY + " (" + throwable + ")");
            return error("FAILED", String.valueOf(throwable), chunkX, chunkY);
        } finally {
            transactionActive = false;
        }
    }

    /** Generate/load, natively populate, observe, save, and release one chunk. */
    public static synchronized String hydrateChunk(int chunkX, int chunkY) {
        if (transactionActive) {
            return error("BUSY", "another source transaction is active", chunkX, chunkY);
        }
        transactionActive = true;
        LoadedChunk held = null;
        enterHydration();
        try {
            String refusal = hydrationRefusal(chunkX, chunkY);
            if (refusal != null) {
                return refusal;
            }
            held = acquire(chunkX, chunkY);
            Snapshot snapshot = scan(held.chunk, true);
            save(held.chunk);
            snapshot.status = "HYDRATED";
            snapshot.mode = held.borrowed ? "native-offscreen" : "loaded";
            return encode(snapshot);
        } catch (Busy busy) {
            return error("BUSY", busy.getMessage(), chunkX, chunkY);
        } catch (Throwable throwable) {
            SAOAgent.log("world sources: hydration failed at " + chunkX + "," + chunkY
                + " (" + throwable + ")");
            return error("FAILED", String.valueOf(throwable), chunkX, chunkY);
        } finally {
            release(held);
            exitHydration();
            transactionActive = false;
        }
    }

    private static String hydrationRefusal(int chunkX, int chunkY) {
        if (GameClient.client || GameServer.server) {
            return error("UNSUPPORTED", "native hydration is single-player only",
                chunkX, chunkY);
        }
        if (Core.getInstance().isNoSave()) {
            return error("NO_SAVE", "the engine has disabled world persistence",
                chunkX, chunkY);
        }
        if (!SAOLootDensityWeave.isReady()) {
            return error("WEAVE_NOT_READY", SAOLootDensityWeave.report(), chunkX, chunkY);
        }
        if (currentCell() == null || WorldStreamer.instance == null) {
            return error("NO_WORLD", "world streamer or cell is unavailable",
                chunkX, chunkY);
        }
        return null;
    }

    private static IsoCell currentCell() {
        return IsoWorld.instance == null ? null : IsoWorld.instance.currentCell;
    }

    private static LoadedChunk acquire(int chunkX, int chunkY) throws Exception {
        IsoCell cell = currentCell();
        IsoChunk live = cell.getChunk(chunkX, chunkY);
        if (live != null) {
            return new LoadedChunk(live, false);
        }

        ArrayList<IsoChunk> pending = new ArrayList<>();
        IsoChunk.loadGridSquare.copyTo(pending);
        for (IsoChunk chunk : pending) {
            if (chunk != null && chunk.wx == chunkX && chunk.wy == chunkY) {
                throw new Busy("target chunk is entering an active map");
            }
        }
        if (WorldStreamer.instance.isBusy()) {
            throw new Busy("world streamer is busy");
        }

        IsoChunk chunk = new IsoChunk(cell);
        try {
            WorldStreamer.instance.addJobInstant(chunk, chunkX, chunkY, chunkX, chunkY);
            IsoChunk.loadGridSquare.remove(chunk);
            if (!chunk.loaded) {
                throw new IllegalStateException("native chunk load did not complete");
            }
            // DoChunkAlways has loaded/generated the chunk, but an off-screen
            // coordinate cannot be adopted by any active IsoChunkMap. Run only
            // the streamer's own pre-live square phase; doLoadGridsquare is a
            // live-map phase and is deliberately not entered here.
            chunk.loadInWorldStreamerThread();
            return new LoadedChunk(chunk, true);
        } catch (Throwable throwable) {
            IsoChunk.loadGridSquare.remove(chunk);
            try {
                chunk.doReuseGridsquares();
            } catch (Throwable cleanup) {
                throwable.addSuppressed(cleanup);
            }
            if (throwable instanceof Exception exception) {
                throw exception;
            }
            throw new RuntimeException(throwable);
        }
    }

    private static void release(LoadedChunk held) {
        if (held == null || !held.borrowed) {
            return;
        }
        try {
            IsoChunk.loadGridSquare.remove(held.chunk);
            held.chunk.doReuseGridsquares();
        } catch (Throwable throwable) {
            SAOAgent.log("world sources: chunk release failed at " + held.chunk.wx + ","
                + held.chunk.wy + " (" + throwable + ")");
        }
    }

    private static void save(IsoChunk chunk) throws Exception {
        chunk.Save(true);
    }

    private static Snapshot scan(IsoChunk chunk, boolean fill) {
        Snapshot snapshot = new Snapshot(chunk.wx, chunk.wy);
        for (int z = chunk.getMinLevel(); z <= chunk.getMaxLevel(); z++) {
            for (int localY = 0; localY < CHUNK_SIZE; localY++) {
                for (int localX = 0; localX < CHUNK_SIZE; localX++) {
                    IsoGridSquare square = chunk.getGridSquare(localX, localY, z);
                    if (square != null) {
                        scanSquare(snapshot, square, fill);
                    }
                }
            }
        }
        for (BaseVehicle vehicle : new ArrayList<>(chunk.vehicles)) {
            // C61 observes vehicle identity but does not mutate its separate
            // VehiclesDB2 persistence surface. Access remains unsupported.
            scanVehicle(snapshot, vehicle, false);
        }
        snapshot.finish();
        return snapshot;
    }

    private static void scanSquare(Snapshot snapshot, IsoGridSquare square, boolean fill) {
        List<IsoObject> objects = square.getObjects();
        for (int objectIndex = 0; objectIndex < objects.size(); objectIndex++) {
            IsoObject object = objects.get(objectIndex);
            if (object == null) {
                continue;
            }
            int count = object.getContainerCount();
            for (int containerIndex = 0; containerIndex < count; containerIndex++) {
                ItemContainer container = object.getContainerByIndex(containerIndex);
                if (container == null) {
                    continue;
                }
                if (fill && !container.isExplored()) {
                    ItemPickerJava.fillContainer(container, lootParticipant());
                    container.setExplored(true);
                    ItemPickerJava.updateOverlaySprite(object);
                }
                snapshot.add(containerSource(snapshot, square, object, container,
                    containerIndex));
            }
            if (object.getFluidCapacity() > 0.0f || !plumbingState(object).isEmpty()) {
                snapshot.add(objectFluidSource(snapshot, square, object));
            }
        }
        for (IsoWorldInventoryObject worldObject
                : new ArrayList<>(square.getWorldObjects())) {
            if (worldObject != null && worldObject.getItem() != null) {
                snapshot.add(groundSource(snapshot, square, worldObject));
            }
        }
    }

    private static void scanVehicle(Snapshot snapshot, BaseVehicle vehicle, boolean fill) {
        if (vehicle == null || vehicle.getParts() == null) {
            return;
        }
        for (int index = 0; index < vehicle.getParts().size(); index++) {
            VehiclePart part = vehicle.getParts().get(index);
            ItemContainer container = part == null ? null : part.getItemContainer();
            if (container == null) {
                continue;
            }
            if (fill && !container.isExplored()) {
                ItemPickerJava.fillContainer(container, lootParticipant());
                container.setExplored(true);
            }
            snapshot.add(vehicleSource(vehicle, part, container));
        }
    }

    private static IsoPlayer lootParticipant() {
        IsoPlayer player = IsoPlayer.getInstance();
        return player != null && Boolean.TRUE.equals(player.getModData().rawget("SAO_ObserverAnchor"))
            ? null : player;
    }

    private static Source containerSource(Snapshot snapshot, IsoGridSquare square,
            IsoObject object, ItemContainer container, int containerIndex) {
        long building = buildingId(square);
        String token = sourceToken(snapshot, object);
        String id = "C:" + token + ":" + containerIndex;
        String physical = object.getClass().getName() + "|" + value(object.getSpriteName())
            + "|" + value(container.getType()) + "|" + building + "|"
            + square.getX() + "|" + square.getY() + "|" + square.getZ()
            + "|" + containerIndex + "|" + token;
        Source source = new Source(id, digest(physical), "container", square.getX(),
            square.getY(), square.getZ(), building, container.isExplored());
        source.containerType = value(container.getType());
        if (container.isExplored()) {
            addItems(source, container.getItems(), 0);
        }
        source.finish();
        return source;
    }

    private static Source objectFluidSource(Snapshot snapshot, IsoGridSquare square,
            IsoObject object) {
        long building = buildingId(square);
        String token = sourceToken(snapshot, object);
        String id = "F:" + token;
        String physical = object.getClass().getName() + "|" + value(object.getSpriteName())
            + "|fluid|" + building + "|" + square.getX() + "|" + square.getY()
            + "|" + square.getZ() + "|" + token;
        Source source = new Source(id, digest(physical), "fluid", square.getX(),
            square.getY(), square.getZ(), building, true);
        source.plumbing = plumbingState(object);
        float amount = object.getFluidAmount();
        Fluid fluid = object.getPrimaryFluid();
        boolean cleanWater = amount > 0.0f && (fluid == null || !fluid.isPoisonous())
            && object.hasWater() && !object.isTaintedWater();
        ItemRow row = ItemRow.fluid(object, amount, fluid, cleanWater, object.isTaintedWater());
        source.items.add(row);
        source.finish();
        return source;
    }

    private static Source groundSource(Snapshot snapshot, IsoGridSquare square,
            IsoWorldInventoryObject worldObject) {
        InventoryItem item = worldObject.getItem();
        String token = itemToken(snapshot, item);
        String id = "G:" + token;
        String physical = value(item.getFullType()) + "|" + item.getID() + "|"
            + square.getX() + "|" + square.getY() + "|" + square.getZ()
            + "|" + token;
        Source source = new Source(id, digest(physical), "ground", square.getX(),
            square.getY(), square.getZ(), buildingId(square), true);
        source.items.add(ItemRow.of(item));
        source.finish();
        return source;
    }

    private static Source vehicleSource(BaseVehicle vehicle, VehiclePart part,
            ItemContainer container) {
        int sqlId = vehicle.getSqlId();
        int partIndex = part.getIndex();
        String id = "V:" + sqlId + ":" + partIndex;
        String physical = sqlId + "|" + partIndex + "|" + value(part.getId())
            + "|" + value(container.getType());
        int x = (int) Math.floor(vehicle.getX());
        int y = (int) Math.floor(vehicle.getY());
        int z = (int) Math.floor(vehicle.getZ());
        Source source = new Source(id, digest(physical), "vehicle", x, y, z, -1,
            container.isExplored());
        source.access = "unsupported";
        source.containerType = value(container.getType());
        if (container.isExplored()) {
            addItems(source, container.getItems(), 0);
        }
        source.finish();
        return source;
    }

    private static void addItems(Source source, List<InventoryItem> items,
            int depth) {
        if (depth > MAX_CONTAINER_DEPTH) {
            throw new IllegalStateException("native container nesting exceeds bound");
        }
        for (InventoryItem item : new ArrayList<>(items)) {
            if (item == null) {
                continue;
            }
            if (source.items.size() >= MAX_ITEMS_PER_SOURCE) {
                throw new IllegalStateException("native source item count exceeds bound");
            }
            source.items.add(ItemRow.of(item));
            if (item instanceof InventoryContainer nested
                    && nested.getInventory() != null) {
                addItems(source, nested.getInventory().getItems(), depth + 1);
            }
        }
    }

    private static String sourceToken(Snapshot snapshot, IsoObject object) {
        Object existing = object.getModData().rawget(SOURCE_TOKEN);
        if (existing instanceof String token && !token.isBlank() && token.length() <= 64) {
            return token;
        }
        if (existing != null) {
            throw new IllegalStateException("invalid native source token");
        }
        String token = UUID.randomUUID().toString();
        object.getModData().rawset(SOURCE_TOKEN, token);
        snapshot.identitiesStamped = true;
        return token;
    }

    private static String itemToken(Snapshot snapshot, InventoryItem item) {
        Object existing = item.getModData().rawget(ITEM_TOKEN);
        if (existing instanceof String token && !token.isBlank() && token.length() <= 64) {
            return token;
        }
        if (existing != null) {
            throw new IllegalStateException("invalid native item source token");
        }
        String token = UUID.randomUUID().toString();
        item.getModData().rawset(ITEM_TOKEN, token);
        snapshot.identitiesStamped = true;
        return token;
    }

    /** Reuse C61's persistent static-holder identity in a loaded private view. */
    static synchronized String privateContainerId(IsoObject object, int containerIndex) {
        if (object == null || containerIndex < 0
                || object.getContainerByIndex(containerIndex) == null) {
            throw new IllegalArgumentException("invalid native container holder");
        }
        Object existing = object.getModData().rawget(SOURCE_TOKEN);
        String token;
        if (existing instanceof String text && !text.isBlank() && text.length() <= 64) {
            token = text;
        } else if (existing == null) {
            token = UUID.randomUUID().toString();
            object.getModData().rawset(SOURCE_TOKEN, token);
        } else {
            throw new IllegalStateException("invalid native source token");
        }
        return "C:" + token + ":" + containerIndex;
    }

    /** Reuse C61's persistent placed-item identity in a loaded private view. */
    static synchronized String privateGroundId(InventoryItem item) {
        if (item == null) throw new IllegalArgumentException("missing native ground item");
        Object existing = item.getModData().rawget(ITEM_TOKEN);
        String token;
        if (existing instanceof String text && !text.isBlank() && text.length() <= 64) {
            token = text;
        } else if (existing == null) {
            token = UUID.randomUUID().toString();
            item.getModData().rawset(ITEM_TOKEN, token);
        } else {
            throw new IllegalStateException("invalid native item source token");
        }
        return "G:" + token;
    }

    static String privateVehicleId(BaseVehicle vehicle, VehiclePart part) {
        if (vehicle == null || part == null || part.getItemContainer() == null) {
            throw new IllegalArgumentException("invalid native vehicle holder");
        }
        return "V:" + vehicle.getSqlId() + ":" + part.getIndex();
    }

    private static long buildingId(IsoGridSquare square) {
        BuildingDef building = square.getBuildingDef();
        return building == null ? -1L : building.getID();
    }

    private static void enterHydration() {
        HYDRATION_DEPTH.set(HYDRATION_DEPTH.get() + 1);
    }

    private static void exitHydration() {
        int depth = HYDRATION_DEPTH.get() - 1;
        if (depth <= 0) {
            HYDRATION_DEPTH.remove();
        } else {
            HYDRATION_DEPTH.set(depth);
        }
    }

    private static String encode(Snapshot snapshot) {
        StringBuilder out = new StringBuilder(4096);
        out.append("H|protocol=").append(PROTOCOL)
            .append("|status=").append(field(snapshot.status))
            .append("|detail=").append(field(snapshot.detail))
            .append("|mode=").append(field(snapshot.mode))
            .append("|cx=").append(snapshot.chunkX)
            .append("|cy=").append(snapshot.chunkY)
            .append("|revision=").append(snapshot.revision)
            .append("|sources=").append(snapshot.sources.size()).append('\n');
        for (Source source : snapshot.sources) {
            out.append("S|id=").append(field(source.id))
                .append("|fp=").append(source.fingerprint)
                .append("|rev=").append(source.revision)
                .append("|kind=").append(source.kind)
                .append("|x=").append(source.x)
                .append("|y=").append(source.y)
                .append("|z=").append(source.z)
                .append("|building=").append(source.buildingId)
                .append("|explored=").append(source.explored ? 1 : 0)
                .append("|state=").append(source.state)
                .append("|access=").append(source.access)
                .append("|container=").append(field(source.containerType));
            if (!source.plumbing.isEmpty()) out.append("|plumbing=").append(source.plumbing);
            if (source.inspected != null) out.append("|inspected=").append(source.inspected ? 1 : 0);
            if (source.generatorCondition != null) out.append("|condition=").append(source.generatorCondition);
            if (source.generatorFuel != null) out.append("|fuel=").append(number(source.generatorFuel)).append("|maxFuel=").append(number(source.generatorMaxFuel));
            if (source.connected != null) out.append("|connected=").append(source.connected ? 1 : 0);
            if (source.active != null) out.append("|active=").append(source.active ? 1 : 0);
            if (source.outside != null) out.append("|outside=").append(source.outside ? 1 : 0);
            if (source.powered != null) out.append("|powered=").append(source.powered ? 1 : 0);
            for (Map.Entry<String, Float> entry : source.quantities.entrySet()) {
                out.append("|q:").append(entry.getKey()).append('=')
                    .append(number(entry.getValue()));
            }
            out.append('\n');
            for (ItemRow item : source.items) {
                out.append("I|source=").append(field(source.id))
                    .append(itemFields(item))
                    .append('\n');
            }
        }
        out.append("E\n");
        return out.toString();
    }

    private static String itemFields(ItemRow item) {
        return "|id=" + item.itemId + "|type=" + field(item.fullType)
            + "|uses=" + item.uses + "|currentUses=" + number(item.currentUses)
            + "|condition=" + item.condition + "|amount=" + number(item.amount)
            + "|fluid=" + field(item.fluid) + "|poison=" + (item.poison ? 1 : 0)
            + "|tainted=" + (item.tainted ? 1 : 0) + "|hydrationAmount=" + number(item.hydrationAmount)
            + "|rotten=" + (item.rotten ? 1 : 0)
            + "|cats=" + field(String.join(",", item.categories));
    }

    private static String error(String status, String detail, int chunkX, int chunkY) {
        return "H|protocol=" + PROTOCOL + "|status=" + field(status)
            + "|detail=" + field(detail) + "|mode=none|cx=" + chunkX
            + "|cy=" + chunkY + "|revision=|sources=0\nE\n";
    }

    private static String field(String value) {
        if (value == null) {
            return "";
        }
        byte[] bytes = value.getBytes(StandardCharsets.UTF_8);
        StringBuilder out = new StringBuilder(bytes.length);
        for (byte raw : bytes) {
            int c = raw & 0xff;
            if (c == '|' || c == '=') {
                out.append('%');
                out.append(Character.forDigit((c >>> 4) & 0xf, 16));
                out.append(Character.forDigit(c & 0xf, 16));
            } else if ((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z')
                    || (c >= '0' && c <= '9') || c == '-' || c == '_'
                    || c == '.' || c == ':' || c == ',') {
                out.append((char) c);
            } else {
                out.append('%');
                out.append(Character.forDigit((c >>> 4) & 0xf, 16));
                out.append(Character.forDigit(c & 0xf, 16));
            }
        }
        return out.toString();
    }

    private static String snapshotRevision(List<Source> sources) {
        StringBuilder exact = new StringBuilder();
        for (Source source : sources) {
            appendLengthPrefixed(exact, source.id);
            appendLengthPrefixed(exact, source.fingerprint);
            appendLengthPrefixed(exact, source.revision);
        }
        return digest(exact.toString());
    }

    private static void appendLengthPrefixed(StringBuilder out, String value) {
        String present = value(value);
        out.append(present.length()).append(':').append(present);
    }

    private static String number(float value) {
        return String.format(Locale.ROOT, "%.6f", value);
    }

    private static String value(String value) {
        return value == null ? "" : value;
    }

    private static String digest(String value) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            byte[] bytes = digest.digest(value.getBytes(StandardCharsets.UTF_8));
            StringBuilder out = new StringBuilder(bytes.length * 2);
            for (byte b : bytes) {
                out.append(Character.forDigit((b >>> 4) & 0xf, 16));
                out.append(Character.forDigit(b & 0xf, 16));
            }
            return out.toString();
        } catch (Exception impossible) {
            throw new IllegalStateException(impossible);
        }
    }

    private enum ItemLocation { SOURCE, CARRIED, CONTAINER }

    private static Located locate(IsoPlayer shell, String sourceId,
            String fingerprint, String revision, int itemId, String itemType,
            int expectedX, int expectedY, int expectedZ) throws ActionRefusal {
        return locate(shell, sourceId, fingerprint, revision, itemId, itemType,
            expectedX, expectedY, expectedZ, ItemLocation.SOURCE);
    }

    private static Located locate(IsoPlayer shell, String sourceId,
            String fingerprint, String revision, int itemId, String itemType,
            int expectedX, int expectedY, int expectedZ, ItemLocation location)
            throws ActionRefusal {
        if (shell == null || sourceId == null || sourceId.isBlank()) {
            throw new ActionRefusal("BAD_REQUEST");
        }
        IsoCell cell = shell.getCell();
        if (cell == null) throw new ActionRefusal("NOT_LOADED");
        String[] parts = sourceId.split(":");
        Source source;
        InventoryItem item = null;
        ItemContainer sourceContainer = null;
        ItemContainer permissionContainer = null;
        IsoWorldInventoryObject worldItem = null;
        IsoGridSquare square = null;
        BaseVehicle sourceVehicle = null;
        VehiclePart sourceVehiclePart = null;

        try {
            if (parts.length == 3 && "C".equals(parts[0])) {
                square = cell.getGridSquare(expectedX, expectedY, expectedZ);
                if (square == null) throw new ActionRefusal("NOT_LOADED");
                int containerIndex = Integer.parseInt(parts[2]);
                IsoObject matched = null;
                // Native PZArrayList has no iterator or iterator-backed copy;
                // use its installed indexed access on the game thread.
                for (int objectIndex = 0; objectIndex < square.getObjects().size(); objectIndex++) {
                    IsoObject object = square.getObjects().get(objectIndex);
                    Object token = object == null ? null
                        : object.getModData().rawget(SOURCE_TOKEN);
                    if (parts[1].equals(token)) {
                        matched = object;
                        break;
                    }
                }
                if (matched == null || containerIndex < 0
                        || containerIndex >= matched.getContainerCount()) {
                    throw new ActionRefusal("SOURCE_MISSING");
                }
                ItemContainer root = matched.getContainerByIndex(containerIndex);
                if (root == null) throw new ActionRefusal("SOURCE_MISSING");
                source = containerSourceKnown(square, matched, root,
                    containerIndex, parts[1]);
                sourceContainer = root;
                permissionContainer = root;
            } else if (parts.length == 2 && "G".equals(parts[0])) {
                if (location != ItemLocation.SOURCE) {
                    throw new ActionRefusal("STORE_SOURCE_UNSUPPORTED");
                }
                square = cell.getGridSquare(expectedX, expectedY, expectedZ);
                if (square == null) throw new ActionRefusal("NOT_LOADED");
                InventoryItem matchedItem = null;
                for (IsoWorldInventoryObject candidate
                        : new ArrayList<>(square.getWorldObjects())) {
                    InventoryItem candidateItem = candidate == null
                        ? null : candidate.getItem();
                    Object token = candidateItem == null ? null
                        : candidateItem.getModData().rawget(ITEM_TOKEN);
                    if (parts[1].equals(token)) {
                        worldItem = candidate;
                        matchedItem = candidateItem;
                        break;
                    }
                }
                if (worldItem == null || matchedItem == null) {
                    throw new ActionRefusal("SOURCE_MISSING");
                }
                source = groundSourceKnown(square, worldItem, parts[1]);
                item = matchedItem;
            } else if (parts.length == 3 && "V".equals(parts[0])) {
                int sqlId = Integer.parseInt(parts[1]);
                int partIndex = Integer.parseInt(parts[2]);
                BaseVehicle matched = null;
                for (BaseVehicle candidate : cell.getVehicles()) {
                    if (candidate != null && candidate.getSqlId() == sqlId) {
                        matched = candidate;
                        break;
                    }
                }
                if (matched == null || matched.isRemovedFromWorld()
                        || partIndex < 0 || matched.getParts() == null
                        || partIndex >= matched.getParts().size()) {
                    throw new ActionRefusal("SOURCE_MISSING");
                }
                VehiclePart part = matched.getParts().get(partIndex);
                ItemContainer root = part == null ? null : part.getItemContainer();
                square = matched.getSquare();
                if (root == null || square == null) {
                    throw new ActionRefusal("SOURCE_MISSING");
                }
                source = vehicleSource(matched, part, root);
                sourceContainer = root;
                permissionContainer = root;
                sourceVehicle = matched;
                sourceVehiclePart = part;
            } else if (parts.length >= 2 && "F".equals(parts[0])) {
                throw new ActionRefusal("FLUID_OBJECT_UNSUPPORTED");
            } else {
                throw new ActionRefusal("BAD_SOURCE_ID");
            }
        } catch (ActionRefusal refusal) {
            throw refusal;
        } catch (Throwable malformed) {
            throw new ActionRefusal("BAD_SOURCE_ID");
        }

        if (!value(fingerprint).equals(source.fingerprint)) {
            throw new ActionRefusal("FINGERPRINT_CHANGED");
        }
        if (revision != null && !value(revision).equals(source.revision)) {
            throw new ActionRefusal("REVISION_CHANGED");
        }
        if (location != ItemLocation.CONTAINER) {
            if (location == ItemLocation.CARRIED) {
                item = findItem(shell.getInventory(), itemId, itemType, 0);
                if (countItemId(shell.getInventory(), itemId, 0) != 1
                        || countItemId(permissionContainer, itemId, 0) != 0) {
                    throw new ActionRefusal("ITEM_CONFLICT");
                }
            } else if (worldItem == null) {
                item = findItem(sourceContainer, itemId, itemType, 0);
                if (item != null) sourceContainer = item.getContainer();
            }
            if (item == null) throw new ActionRefusal("ITEM_MISSING");
            if (item.getID() != itemId
                    || !value(itemType).equals(value(item.getFullType()))) {
                throw new ActionRefusal("ITEM_CHANGED");
            }
        }
        return new Located(source, item, sourceContainer, permissionContainer,
            worldItem, square, sourceVehicle, sourceVehiclePart);
    }

    private static Source containerSourceKnown(IsoGridSquare square,
            IsoObject object, ItemContainer container, int containerIndex,
            String token) {
        long building = buildingId(square);
        String id = "C:" + token + ":" + containerIndex;
        Source source = new Source(id, containerFingerprint(square, object, container,
            containerIndex, token), "container", square.getX(), square.getY(),
            square.getZ(), building, container.isExplored());
        source.containerType = value(container.getType());
        if (container.isExplored()) addItems(source, container.getItems(), 0);
        source.finish();
        return source;
    }

    private static String containerFingerprint(IsoGridSquare square,
            IsoObject object, ItemContainer container, int containerIndex, String token) {
        String physical = object.getClass().getName() + "|"
            + value(object.getSpriteName()) + "|" + value(container.getType())
            + "|" + buildingId(square) + "|" + square.getX() + "|" + square.getY()
            + "|" + square.getZ() + "|" + containerIndex + "|" + token;
        return digest(physical);
    }

    private static Source groundSourceKnown(IsoGridSquare square,
            IsoWorldInventoryObject worldObject, String token) {
        InventoryItem item = worldObject.getItem();
        String id = "G:" + token;
        String physical = value(item.getFullType()) + "|" + item.getID() + "|"
            + square.getX() + "|" + square.getY() + "|" + square.getZ()
            + "|" + token;
        Source source = new Source(id, digest(physical), "ground", square.getX(),
            square.getY(), square.getZ(), buildingId(square), true);
        source.items.add(ItemRow.of(item));
        source.finish();
        return source;
    }

    private static InventoryItem findItem(ItemContainer container, int itemId,
            String itemType, int depth) {
        if (container == null || depth > MAX_CONTAINER_DEPTH) return null;
        for (InventoryItem candidate : new ArrayList<>(container.getItems())) {
            if (candidate == null) continue;
            if (candidate.getID() == itemId
                    && value(itemType).equals(value(candidate.getFullType()))) {
                return candidate;
            }
            if (candidate instanceof InventoryContainer nested) {
                InventoryItem found = findItem(nested.getInventory(), itemId,
                    itemType, depth + 1);
                if (found != null) return found;
            }
        }
        return null;
    }

    static IsoGridSquare interactionSquare(IsoPlayer shell,
            IsoGridSquare source) {
        if (shell == null || source == null || shell.getCell() == null) return null;
        IsoGridSquare best = null;
        float bestDistance = Float.POSITIVE_INFINITY;
        for (int dy = -1; dy <= 1; dy++) {
            for (int dx = -1; dx <= 1; dx++) {
                IsoGridSquare candidate = shell.getCell().getGridSquare(
                    source.getX() + dx, source.getY() + dy, source.getZ());
                if (candidate == null || !candidate.isFree(false)) continue;
                if (candidate != source && candidate.isSomethingTo(source)) continue;
                float px = candidate.getX() + 0.5f - shell.getX();
                float py = candidate.getY() + 0.5f - shell.getY();
                float distance = px * px + py * py;
                if (best == null || distance < bestDistance) {
                    best = candidate;
                    bestDistance = distance;
                }
            }
        }
        return best;
    }

    /** Use the same named part area that vanilla vehicle interactions path to. */
    static IsoGridSquare vehicleInteractionSquare(BaseVehicle vehicle,
            VehiclePart part) {
        if (vehicle == null || part == null || part.getArea() == null
                || part.getArea().isBlank()) return null;
        IsoGridSquare square = vehicle.getSquareForArea(part.getArea());
        return square != null && square.isFree(false) ? square : null;
    }

    private static boolean squareWithinReach(IsoPlayer shell,
            IsoGridSquare square) {
        if (shell == null || square == null || shell.getCell() == null
                || square.getCell() != shell.getCell()
                || square.getZ() != (int) shell.getZ()) return false;
        IsoGridSquare here = shell.getCurrentSquare();
        if (here == null) return false;
        float dx = shell.getX() - (square.getX() + 0.5f);
        float dy = shell.getY() - (square.getY() + 0.5f);
        return dx * dx + dy * dy <= 4.0f && !here.isSomethingTo(square);
    }

    private static float fluidAmount(InventoryItem item) {
        FluidContainer fluids = item == null
            ? null : item.getFluidContainerFromSelfOrWorldItem();
        return fluids == null ? 0.0f : fluids.getAmount();
    }

    private static final class ActionRefusal extends Exception {
        final String code;
        ActionRefusal(String code) {
            super(code);
            this.code = code;
        }
    }

    private static final class Located {
        final Source source;
        final InventoryItem item;
        final ItemContainer sourceContainer;
        final ItemContainer permissionContainer;
        final IsoWorldInventoryObject worldItem;
        final IsoGridSquare square;
        final BaseVehicle vehicle;
        final VehiclePart vehiclePart;
        Located(Source source, InventoryItem item, ItemContainer sourceContainer,
                ItemContainer permissionContainer,
                IsoWorldInventoryObject worldItem, IsoGridSquare square,
                BaseVehicle vehicle, VehiclePart vehiclePart) {
            this.source = source;
            this.item = item;
            this.sourceContainer = sourceContainer;
            this.permissionContainer = permissionContainer;
            this.worldItem = worldItem;
            this.square = square;
            this.vehicle = vehicle;
            this.vehiclePart = vehiclePart;
        }
    }

    private static final class InspectionBinding {
        final String id, fingerprint;
        final java.lang.ref.WeakReference<IsoObject> object;
        final java.lang.ref.WeakReference<ItemContainer> container;
        final java.lang.ref.WeakReference<IsoGridSquare> square;
        final int index;
        final int sourceX, sourceY, sourceZ, x, y, z;
        final double distance;
        String observedRevision;
        InspectionBinding(String id, String fingerprint, IsoObject object,
                ItemContainer container, int index, IsoGridSquare square,
                IsoGridSquare approach, IsoPlayer shell) {
            this.id = id; this.fingerprint = fingerprint;
            this.object = new java.lang.ref.WeakReference<>(object);
            this.container = new java.lang.ref.WeakReference<>(container);
            this.square = new java.lang.ref.WeakReference<>(square);
            this.index = index;
            this.sourceX = square.getX(); this.sourceY = square.getY(); this.sourceZ = square.getZ();
            this.x = approach.getX(); this.y = approach.getY(); this.z = approach.getZ();
            double dx = approach.getX() + 0.5 - shell.getX();
            double dy = approach.getY() + 0.5 - shell.getY();
            this.distance = dx * dx + dy * dy;
        }
    }

    private static final class ActionBinding {
        InventoryItem item;
        final ItemContainer sourceContainer;
        final ItemContainer originContainer;
        final ItemContainer permissionContainer;
        final IsoWorldInventoryObject worldItem;
        String category = "";
        int usesBefore;
        float currentUsesBefore;
        float amountBefore;
        float hungerBefore;
        float thirstBefore;
        boolean useStarted;
        boolean settled;

        ActionBinding(Located located) {
            item = located.item;
            sourceContainer = located.sourceContainer;
            originContainer = item == null ? null : item.getContainer();
            permissionContainer = located.permissionContainer;
            worldItem = located.worldItem;
        }

        ActionBinding(InventoryItem item) {
            this.item = item;
            sourceContainer = null;
            originContainer = item == null ? null : item.getContainer();
            permissionContainer = null;
            worldItem = null;
        }
    }

    private static final class Busy extends Exception {
        Busy(String message) {
            super(message);
        }
    }

    private static final class LoadedChunk {
        final IsoChunk chunk;
        final boolean borrowed;

        LoadedChunk(IsoChunk chunk, boolean borrowed) {
            this.chunk = chunk;
            this.borrowed = borrowed;
        }
    }

    private static final class Snapshot {
        final int chunkX;
        final int chunkY;
        final ArrayList<Source> sources = new ArrayList<>();
        final Map<String, Source> byId = new LinkedHashMap<>();
        String status = "OBSERVED";
        String detail = "";
        String mode = "loaded";
        String revision = "";
        boolean identitiesStamped;

        Snapshot(int chunkX, int chunkY) {
            this.chunkX = chunkX;
            this.chunkY = chunkY;
        }

        void add(Source source) {
            if (sources.size() >= MAX_SOURCES_PER_CHUNK) {
                throw new IllegalStateException("native chunk source count exceeds bound");
            }
            Source previous = byId.put(source.id, source);
            if (previous != null) {
                throw new IllegalStateException("duplicate native source identity " + source.id);
            }
            sources.add(source);
        }

        void finish() {
            sources.sort(Comparator.comparing(source -> source.id));
            revision = snapshotRevision(sources);
        }
    }

    private static final class Source {
        final String id;
        final String fingerprint;
        final String kind;
        final int x;
        final int y;
        final int z;
        final long buildingId;
        final boolean explored;
        final ArrayList<ItemRow> items = new ArrayList<>();
        final Map<String, Float> quantities = new LinkedHashMap<>();
        String containerType = "";
        String plumbing = "";
        Boolean inspected, connected, active, outside, powered;
        Integer generatorCondition;
        Float generatorFuel, generatorMaxFuel;
        String revision = "";
        String state = "unknown";
        String access = "unknown";
        Source(String id, String fingerprint, String kind, int x, int y, int z,
                long buildingId, boolean explored) {
            this.id = id;
            this.fingerprint = fingerprint;
            this.kind = kind;
            this.x = x;
            this.y = y;
            this.z = z;
            this.buildingId = buildingId;
            this.explored = explored;
        }

        void finish() {
            items.sort(Comparator.comparingInt(row -> row.itemId));
            StringBuilder exact = new StringBuilder(explored ? "explored\n" : "unknown\n");
            if (!plumbing.isEmpty()) exact.append("plumbing=").append(plumbing).append('\n');
            if (inspected != null) exact.append("utility=").append(kind).append(':').append(inspected).append(':')
                .append(generatorCondition).append(':').append(generatorFuel).append(':').append(generatorMaxFuel).append(':')
                .append(connected).append(':').append(active).append(':').append(outside).append(':').append(powered).append('\n');
            for (ItemRow item : items) {
                item.addQuantities(quantities);
                exact.append(item.revisionLine()).append('\n');
            }
            revision = digest(exact.toString());
            if (!explored) {
                state = "unknown";
            } else if ("generator".equals(kind) || "power-consumer".equals(kind)) {
                state = "available";
            } else if ("fluid".equals(kind)) {
                state = !items.isEmpty() && items.get(0).amount > 0.0f
                    ? "available" : "spent";
            } else if (items.isEmpty()) {
                state = "spent";
            } else {
                state = "available";
            }
        }
    }

    private static final class ItemRow {
        final int itemId;
        final String fullType;
        final int uses;
        final float currentUses;
        final int condition;
        final float amount;
        final String fluid;
        final boolean poison;
        final boolean rotten;
        final boolean cleanWater;
        final boolean tainted;
        final float hydrationAmount;
        final ArrayList<String> categories;
        ItemRow(int itemId, String fullType, int uses, float currentUses,
                int condition, float amount, String fluid,
                boolean poison, boolean rotten, boolean cleanWater, boolean tainted, float hydrationAmount,
                ArrayList<String> categories) {
            this.itemId = itemId;
            this.fullType = fullType;
            this.uses = uses;
            this.currentUses = currentUses;
            this.condition = condition;
            this.amount = amount;
            this.fluid = fluid;
            this.poison = poison;
            this.rotten = rotten;
            this.cleanWater = cleanWater;
            this.tainted = tainted;
            this.hydrationAmount = hydrationAmount;
            this.categories = categories;
        }

        static ItemRow of(InventoryItem item) {
            FluidContainer fluids = item.getFluidContainerFromSelfOrWorldItem();
            float amount = fluids == null ? 0.0f : fluids.getAmount();
            Fluid primary = fluids == null ? null : fluids.getPrimaryFluid();
            boolean poison = fluids != null && fluids.isPoisonous();
            boolean rotten = item.IsRotten();
            boolean cleanWater = fluids != null && amount > 0.0f
                && fluids.isWaterSource() && !poison && !fluids.isTainted();
            ArrayList<String> categories = categories(item, fluids, amount,
                cleanWater);
            return new ItemRow(item.getID(), value(item.getFullType()), item.getUses(),
                item.getCurrentUsesFloat(), item.getCondition(), amount,
                primary == null ? "" : value(primary.getFluidTypeString()),
                poison, rotten, cleanWater, fluids != null && fluids.isTainted(),
                Math.max(0.0f, SAONeeds.hydrationAmount(fluids)), categories);
        }

        static ItemRow fluid(IsoObject object, float amount, Fluid fluid,
                boolean cleanWater, boolean tainted) {
            ArrayList<String> categories = new ArrayList<>();
            if (amount > 0.0f && (fluid == null || !fluid.isPoisonous())) {
                categories.add("drink");
                if (cleanWater) {
                    categories.add("water");
                }
            }
            return new ItemRow(0, "", 0, 0.0f, 0, amount,
                fluid == null ? "" : value(fluid.getFluidTypeString()),
                fluid != null && fluid.isPoisonous(), false, cleanWater, tainted,
                cleanWater ? amount : 0.0f,
                categories);
        }

        void addQuantities(Map<String, Float> into) {
            for (String category : categories) {
                float quantity = ("water".equals(category) || "drink".equals(category))
                    && amount > 0.0f ? amount : 1.0f;
                into.put(category, into.getOrDefault(category, 0.0f) + quantity);
            }
        }

        String revisionLine() {
            return itemId + "|" + fullType + "|" + uses + "|"
                + Float.toHexString(currentUses) + "|" + condition + "|"
                + Float.toHexString(amount) + "|" + fluid + "|" + poison + "|"
                + rotten + "|" + tainted + "|" + Float.toHexString(hydrationAmount)
                + "|" + String.join(",", categories);
        }

        private static ArrayList<String> categories(InventoryItem item,
                FluidContainer fluids, float amount, boolean cleanWater) {
            ArrayList<String> out = new ArrayList<>();
            if (SAONeeds.isEdibleMaterial(item)) out.add("food");
            if (cleanWater || (fluids == null && item.isWaterSource())) out.add("water");
            if (fluids != null && amount > 0.0f && !fluids.isPoisonous()) out.add("drink");
            if (SAONeeds.wantsMaterial(item, "weapon")) out.add("weapons");
            if (SAONeeds.wantsMaterial(item, "medical")) out.add("medicine");
            if (SAONeeds.wantsMaterial(item, "tool")) out.add("tools");
            if (SAONeeds.wantsMaterial(item, "device")) out.add("device");
            if (SAONeeds.wantsMaterial(item, "smokes")) out.add("smokes");
            if (SAONeeds.wantsMaterial(item, "instrument")) out.add("instrument");
            if (SAOLeisureMaterials.recognizes(item.getFullType())) out.add("leisure-material");
            if (SAONeeds.wantsMaterial(item, "memento")) out.add("memento");
            if (SAONeeds.wantsMaterial(item, "reading")) out.add("reading");
            if (SAONeeds.wantsMaterial(item, "glass-pane")) out.add("glass-pane");
            if (SAONeeds.wantsMaterial(item, "hammer")) out.add("hammer");
            if (SAONeeds.wantsMaterial(item, "pipe-wrench")) out.add("pipe-wrench");
            if (SAONeeds.wantsMaterial(item, "garbage-bag")) out.add("garbage-bag");
            if (SAONeeds.wantsMaterial(item, "tarp")) out.add("tarp");
            if (SAONeeds.wantsMaterial(item, "electronics-scrap")) out.add("electronics-scrap");
            if (SAONeeds.wantsMaterial(item, "petrol")) out.add("petrol");
            if (SAONeeds.wantsMaterial(item, "generator-manual")) out.add("generator-manual");
            if (SAONeeds.wantsMaterial(item, "plank")) out.add("plank");
            if (SAONeeds.wantsMaterial(item, "log")) out.add("log");
            if (SAONeeds.wantsMaterial(item, "saw")) out.add("saw");
            if (SAONeeds.wantsMaterial(item, "file")) out.add("file");
            if (SAONeeds.wantsMaterial(item, "whetstone")) out.add("whetstone");
            if (SAONeeds.wantsMaterial(item, "nails")) out.add("nails");
            if (SAONeeds.wantsMaterial(item, "fuel")) out.add("fuel");
            Collections.sort(out);
            return out;
        }
    }
}
