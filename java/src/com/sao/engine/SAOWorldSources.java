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
    private static final int CHUNK_SIZE = IsoChunkMap.CHUNK_SIZE_IN_SQUARES;
    private static final ThreadLocal<Integer> HYDRATION_DEPTH =
        ThreadLocal.withInitial(() -> 0);
    private static final Map<IsoPlayer, ActionBinding> ACTIONS =
        new WeakHashMap<>();
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
        if (!(row.categories.contains("food") || row.categories.contains("water"))) {
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
                    ItemPickerJava.fillContainer(container, IsoPlayer.getInstance());
                    container.setExplored(true);
                    ItemPickerJava.updateOverlaySprite(object);
                }
                snapshot.add(containerSource(snapshot, square, object, container,
                    containerIndex));
            }
            if (object.getFluidCapacity() > 0.0f) {
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
                ItemPickerJava.fillContainer(container, IsoPlayer.getInstance());
                container.setExplored(true);
            }
            snapshot.add(vehicleSource(vehicle, part, container));
        }
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
        float amount = object.getFluidAmount();
        Fluid fluid = object.getPrimaryFluid();
        boolean cleanWater = amount > 0.0f && fluid != null
            && object.hasWater() && !object.isTaintedWater() && !fluid.isPoisonous();
        ItemRow row = ItemRow.fluid(object, amount, fluid, cleanWater);
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
                for (IsoObject object : square.getObjects()) {
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
        String physical = object.getClass().getName() + "|"
            + value(object.getSpriteName()) + "|" + value(container.getType())
            + "|" + building + "|" + square.getX() + "|" + square.getY()
            + "|" + square.getZ() + "|" + containerIndex + "|" + token;
        Source source = new Source(id, digest(physical), "container",
            square.getX(), square.getY(), square.getZ(), building,
            container.isExplored());
        source.containerType = value(container.getType());
        if (container.isExplored()) addItems(source, container.getItems(), 0);
        source.finish();
        return source;
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

    private static IsoGridSquare interactionSquare(IsoPlayer shell,
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
    private static IsoGridSquare vehicleInteractionSquare(BaseVehicle vehicle,
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
            for (ItemRow item : items) {
                item.addQuantities(quantities);
                exact.append(item.revisionLine()).append('\n');
            }
            revision = digest(exact.toString());
            if (!explored) {
                state = "unknown";
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
        final ArrayList<String> categories;
        ItemRow(int itemId, String fullType, int uses, float currentUses,
                int condition, float amount, String fluid,
                boolean poison, boolean rotten, boolean cleanWater,
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
                poison, rotten, cleanWater, categories);
        }

        static ItemRow fluid(IsoObject object, float amount, Fluid fluid,
                boolean cleanWater) {
            ArrayList<String> categories = new ArrayList<>();
            if (amount > 0.0f && (fluid == null || !fluid.isPoisonous())) {
                categories.add("drink");
                if (cleanWater) {
                    categories.add("water");
                }
            }
            return new ItemRow(0, "", 0, 0.0f, 0, amount,
                fluid == null ? "" : value(fluid.getFluidTypeString()),
                fluid != null && fluid.isPoisonous(), false, cleanWater,
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
                + rotten + "|" + String.join(",", categories);
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
            if (SAONeeds.wantsMaterial(item, "memento")) out.add("memento");
            if (SAONeeds.wantsMaterial(item, "reading")) out.add("reading");
            if (SAONeeds.wantsMaterial(item, "plank")) out.add("plank");
            if (SAONeeds.wantsMaterial(item, "nails")) out.add("nails");
            if (SAONeeds.wantsMaterial(item, "fuel")) out.add("fuel");
            Collections.sort(out);
            return out;
        }
    }
}
