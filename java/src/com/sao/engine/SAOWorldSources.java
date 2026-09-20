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
                    .append("|id=").append(item.itemId)
                    .append("|type=").append(field(item.fullType))
                    .append("|uses=").append(item.uses)
                    .append("|amount=").append(number(item.amount))
                    .append("|fluid=").append(field(item.fluid))
                    .append("|poison=").append(item.poison ? 1 : 0)
                    .append("|rotten=").append(item.rotten ? 1 : 0)
                    .append("|cats=").append(field(String.join(",", item.categories)))
                    .append('\n');
            }
        }
        out.append("E\n");
        return out.toString();
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
        final float amount;
        final String fluid;
        final boolean poison;
        final boolean rotten;
        final boolean cleanWater;
        final ArrayList<String> categories;
        ItemRow(int itemId, String fullType, int uses, float amount, String fluid,
                boolean poison, boolean rotten, boolean cleanWater,
                ArrayList<String> categories) {
            this.itemId = itemId;
            this.fullType = fullType;
            this.uses = uses;
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
                amount, primary == null ? "" : value(primary.getFluidTypeString()),
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
            return new ItemRow(0, "", 0, amount,
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
