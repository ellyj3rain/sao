package com.sao.engine;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Comparator;
import java.util.HashSet;
import java.util.IdentityHashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import zombie.characters.IsoGameCharacter;
import zombie.characters.IsoPlayer;
import zombie.inventory.InventoryItem;
import zombie.inventory.ItemContainer;
import zombie.inventory.types.InventoryContainer;
import zombie.iso.IsoCell;
import zombie.iso.IsoGridSquare;
import zombie.iso.IsoObject;
import zombie.iso.objects.IsoDeadBody;
import zombie.iso.objects.IsoWorldInventoryObject;
import zombie.vehicles.BaseVehicle;
import zombie.vehicles.VehiclePart;

/**
 * A fresh, read-only view of one person's native inventory ground.
 *
 * Project Zomboid remains the owner. This class persists nothing, moves
 * nothing and computes no household total. A loaded view records the exact
 * direct holder of recursively carried and bounded loaded items. A dormant
 * view records the same carried identities from the validated v4 manifest and
 * explicitly leaves world access unknown.
 */
public final class SAOPrivateInventory {
    private static final String PROTOCOL = "SAOPI1";
    private static final int MAX_DEPTH = 64;
    private static final int MAX_ITEMS = 32767;
    private static final int MAX_HOLDERS = 4096;
    private static final int MAX_RADIUS = 64;

    private SAOPrivateInventory() { }

    /** One exact item and its direct parent inside a root native holder. */
    public record ItemRef(String holderId, Integer parentItemId,
            InventoryItem item, int itemId, String fullType) { }

    /** One current native root holder. Items are detached list entries only. */
    public record Holder(String id, String kind, int x, int y, int z,
            String access, String contents, ItemContainer container,
            IsoWorldInventoryObject worldObject, List<ItemRef> items) { }

    /** One actor-scoped observation. No aggregate stock is represented. */
    public record View(String personId, String representation,
            String carriedCoverage, String worldCoverage, String revision,
            List<Holder> holders) { }

    /**
     * Complete recursive carriage for loaded decisions. The returned list is a
     * copy; item objects remain the engine's exact objects.
     */
    public static ArrayList<InventoryItem> carriedItems(IsoGameCharacter person) {
        ArrayList<InventoryItem> found = new ArrayList<>();
        if (person == null || person.getInventory() == null) return found;
        collectItems(person.getInventory(), found,
            Collections.newSetFromMap(new IdentityHashMap<>()), 0);
        return found;
    }

    /** Complete recursive contents of any native container, as detached rows. */
    public static ArrayList<InventoryItem> containerItems(ItemContainer container) {
        ArrayList<InventoryItem> found = new ArrayList<>();
        collectItems(container, found,
            Collections.newSetFromMap(new IdentityHashMap<>()), 0);
        return found;
    }

    /** The engine-owned root that governs access to a nested item container. */
    public static ItemContainer rootContainer(ItemContainer container) {
        ItemContainer current = container;
        Set<ItemContainer> seen = Collections.newSetFromMap(
            new IdentityHashMap<>());
        while (current != null && seen.add(current)) {
            InventoryItem containing = current.getContainingItem();
            ItemContainer parent = containing == null ? null
                : containing.getContainer();
            if (parent == null) return current;
            current = parent;
        }
        return null;
    }

    /** Fresh recursively held items on nearby corpse surfaces. */
    public static ArrayList<InventoryItem> nearbyCorpseItems(IsoPlayer person,
            int radius) {
        ArrayList<InventoryItem> found = new ArrayList<>();
        for (Holder holder : loadedView(person, radius).holders()) {
            if (!"corpse".equals(holder.kind())
                    || "refused".equals(holder.access())
                    || !"complete".equals(holder.contents())) continue;
            for (ItemRef ref : holder.items()) {
                if (ref.item() != null) found.add(ref.item());
            }
        }
        return found;
    }

    private static void collectItems(ItemContainer container,
            ArrayList<InventoryItem> found, Set<ItemContainer> seen, int depth) {
        if (container == null || !seen.add(container)) return;
        if (depth > MAX_DEPTH || found.size() > MAX_ITEMS) {
            throw new IllegalStateException("native carried inventory exceeds bound");
        }
        for (InventoryItem item : new ArrayList<>(container.getItems())) {
            if (item == null || found.size() >= MAX_ITEMS) {
                throw new IllegalStateException("invalid native carried inventory");
            }
            found.add(item);
            if (item instanceof InventoryContainer nested) {
                collectItems(nested.getInventory(), found, seen, depth + 1);
            }
        }
    }

    /** Resolve an exact recursively carried item at execution time. */
    public static InventoryItem carriedItem(IsoGameCharacter person, int itemId,
            String fullType) {
        for (InventoryItem item : carriedItems(person)) {
            if (item.getID() == itemId
                    && value(item.getFullType()).equals(value(fullType))) return item;
        }
        return null;
    }

    /** A complete carried-only view used by decisions that do not inspect ground. */
    public static View carriedView(IsoPlayer person) {
        if (person == null || person.getInventory() == null) {
            return refused("", "loaded", "missing-body");
        }
        String personId = personId(person);
        String holderId = "P:" + personId;
        Holder carried = containerHolder(holderId, "carried", 0, 0, 0,
            "held", "complete", person.getInventory());
        return finish(personId, "loaded", "complete", "not-observed",
            List.of(carried));
    }

    /**
     * Current loaded holders in a bounded area around this person. Static,
     * vehicle, corpse and placed-item surfaces retain distinct identities.
     */
    public static View loadedView(IsoPlayer person, int radius) {
        if (person == null || person.getInventory() == null || person.getCell() == null) {
            return refused("", "loaded", "missing-body-or-cell");
        }
        int bounded = Math.max(0, Math.min(MAX_RADIUS, radius));
        String personId = personId(person);
        ArrayList<Holder> holders = new ArrayList<>();
        holders.add(containerHolder("P:" + personId, "carried", 0, 0, 0,
            "held", "complete", person.getInventory()));

        IsoCell cell = person.getCell();
        int cx = (int) person.getX();
        int cy = (int) person.getY();
        int cz = (int) person.getZ();
        Set<ItemContainer> seenContainers = Collections.newSetFromMap(
            new IdentityHashMap<>());
        seenContainers.add(person.getInventory());
        Set<IsoWorldInventoryObject> seenGround = Collections.newSetFromMap(
            new IdentityHashMap<>());

        for (int zOff = -1; zOff <= 1; zOff++) {
            for (int dy = -bounded; dy <= bounded; dy++) {
                for (int dx = -bounded; dx <= bounded; dx++) {
                    if (holders.size() >= MAX_HOLDERS) {
                        throw new IllegalStateException("private inventory holder bound exceeded");
                    }
                    IsoGridSquare square = cell.getGridSquare(cx + dx, cy + dy,
                        cz + zOff);
                    if (square == null) continue;
                    addSquareHolders(person, square, holders, seenContainers,
                        seenGround);
                }
            }
        }
        addVehicleHolders(person, bounded, holders, seenContainers);
        return finish(personId, "loaded", "complete", "loaded-bounded",
            holders);
    }

    private static void addSquareHolders(IsoPlayer person, IsoGridSquare square,
            List<Holder> holders, Set<ItemContainer> seenContainers,
            Set<IsoWorldInventoryObject> seenGround) {
        List<IsoObject> objects = square.getObjects();
        for (int objectIndex = 0; objectIndex < objects.size(); objectIndex++) {
            IsoObject object = objects.get(objectIndex);
            if (object == null) continue;
            int count = object.getContainerCount();
            for (int containerIndex = 0; containerIndex < count; containerIndex++) {
                ItemContainer container = object.getContainerByIndex(containerIndex);
                if (container == null || !seenContainers.add(container)) continue;
                String access = SAONeeds.containerAccessibleNow(person, container)
                    ? "now" : "approach";
                String contents = container.isExplored() ? "complete" : "unknown";
                holders.add(containerHolder(
                    SAOWorldSources.privateContainerId(object, containerIndex),
                    "container", square.getX(), square.getY(), square.getZ(),
                    access, contents, container));
            }
        }
        for (IsoWorldInventoryObject worldObject
                : new ArrayList<>(square.getWorldObjects())) {
            if (worldObject == null || worldObject.getItem() == null
                    || !seenGround.add(worldObject)) continue;
            String access = squareWithinReach(person, square) ? "now" : "approach";
            holders.add(groundHolder(SAOWorldSources.privateGroundId(
                worldObject.getItem()), square, access, worldObject));
        }
        List<IsoDeadBody> bodies = square.getDeadBodys();
        if (bodies == null) return;
        for (IsoDeadBody body : new ArrayList<>(bodies)) {
            ItemContainer container = body == null ? null : body.getContainer();
            if (container == null || !seenContainers.add(container)) continue;
            String access = SAONeeds.containerAccessibleNow(person, container)
                ? "now" : "approach";
            holders.add(containerHolder("D:" + body.getObjectIDAsLong(), "corpse",
                square.getX(), square.getY(), square.getZ(), access, "complete",
                container));
        }
    }

    private static void addVehicleHolders(IsoPlayer person, int radius,
            List<Holder> holders, Set<ItemContainer> seenContainers) {
        IsoCell cell = person.getCell();
        float limit = (float) radius * radius;
        for (BaseVehicle vehicle : new ArrayList<>(cell.getVehicles())) {
            if (vehicle == null || vehicle.isRemovedFromWorld()) continue;
            float dx = vehicle.getX() - person.getX();
            float dy = vehicle.getY() - person.getY();
            if (dx * dx + dy * dy > limit || vehicle.getParts() == null) continue;
            for (int index = 0; index < vehicle.getParts().size(); index++) {
                VehiclePart part = vehicle.getParts().get(index);
                ItemContainer container = part == null ? null : part.getItemContainer();
                if (container == null || !seenContainers.add(container)) continue;
                String access = vehicle.canAccessContainer(index, person)
                    ? (SAONeeds.containerAccessibleNow(person, container)
                        ? "now" : "approach")
                    : "refused";
                String contents = container.isExplored() ? "complete" : "unknown";
                holders.add(containerHolder(SAOWorldSources.privateVehicleId(
                    vehicle, part), "vehicle", (int) Math.floor(vehicle.getX()),
                    (int) Math.floor(vehicle.getY()), (int) Math.floor(vehicle.getZ()),
                    access, contents, container));
            }
        }
    }

    /** Exact carried identities from a supported dormant envelope. */
    public static View dormantView(String personId, String packed) {
        String normalized = normalizePersonId(personId);
        try {
            List<SAONativeSnapshot.InventoryFact> facts =
                SAONativeSnapshot.inventoryManifest(packed);
            String holderId = "P:" + normalized;
            ArrayList<ItemRef> items = new ArrayList<>();
            for (SAONativeSnapshot.InventoryFact fact : facts) {
                items.add(new ItemRef(holderId, fact.parentItemId(), null,
                    fact.itemId(), fact.fullType()));
            }
            Holder carried = new Holder(holderId, "carried", 0, 0, 0, "held",
                "complete", null, null, List.copyOf(items));
            return finish(normalized, "dormant", "complete", "unknown",
                List.of(carried));
        } catch (Exception unavailable) {
            return refused(normalized, "dormant", "unsupported-or-invalid-snapshot");
        }
    }

    public static String encodeLoaded(IsoPlayer person, int radius) {
        return encode(loadedView(person, radius));
    }

    public static String encodeDormant(String personId, String packed) {
        return encode(dormantView(personId, packed));
    }

    public static boolean dormantHasRadio(String packed) {
        try {
            for (SAONativeSnapshot.InventoryFact fact
                    : SAONativeSnapshot.inventoryManifest(packed)) {
                var definition = zombie.scripting.ScriptManager.instance
                    .FindItem(fact.fullType());
                if (definition != null
                        && definition.getItemType()
                            == zombie.scripting.objects.ItemType.RADIO
                        && !definition.isTelevision
                        && "Communications".equals(
                            definition.getDisplayCategory())) return true;
            }
        } catch (Exception unavailable) { }
        return false;
    }

    public static boolean isRadioReceiver(InventoryItem item) {
        if (item == null) return false;
        var definition = zombie.scripting.ScriptManager.instance
            .FindItem(item.getFullType());
        return definition != null
            && definition.getItemType() == zombie.scripting.objects.ItemType.RADIO
            && !definition.isTelevision
            && "Communications".equals(definition.getDisplayCategory());
    }

    private static Holder containerHolder(String id, String kind, int x, int y,
            int z, String access, String contents, ItemContainer container) {
        ArrayList<ItemRef> items = new ArrayList<>();
        if ("complete".equals(contents)) {
            collectRefs(id, container, null, items,
                Collections.newSetFromMap(new IdentityHashMap<>()), 0);
        }
        items.sort(Comparator.comparingInt(ItemRef::itemId));
        return new Holder(id, kind, x, y, z, access, contents, container, null,
            List.copyOf(items));
    }

    private static Holder groundHolder(String id, IsoGridSquare square,
            String access, IsoWorldInventoryObject worldObject) {
        InventoryItem item = worldObject.getItem();
        ItemRef ref = new ItemRef(id, null, item, item.getID(),
            value(item.getFullType()));
        return new Holder(id, "ground", square.getX(), square.getY(), square.getZ(),
            access, "complete", null, worldObject, List.of(ref));
    }

    private static void collectRefs(String holderId, ItemContainer container,
            Integer parentItemId, List<ItemRef> out, Set<ItemContainer> seen,
            int depth) {
        if (container == null || !seen.add(container) || depth > MAX_DEPTH) {
            if (container != null) {
                throw new IllegalStateException("invalid native inventory nesting");
            }
            return;
        }
        for (InventoryItem item : new ArrayList<>(container.getItems())) {
            if (item == null || out.size() >= MAX_ITEMS) {
                throw new IllegalStateException("invalid native inventory item");
            }
            out.add(new ItemRef(holderId, parentItemId, item, item.getID(),
                value(item.getFullType())));
            if (item instanceof InventoryContainer nested) {
                collectRefs(holderId, nested.getInventory(), item.getID(), out,
                    seen, depth + 1);
            }
        }
    }

    private static View finish(String personId, String representation,
            String carriedCoverage, String worldCoverage, List<Holder> input) {
        ArrayList<Holder> holders = new ArrayList<>(input);
        holders.sort(Comparator.comparing(Holder::id));
        StringBuilder exact = new StringBuilder();
        for (Holder holder : holders) {
            append(exact, holder.id());
            append(exact, holder.kind());
            append(exact, holder.access());
            append(exact, holder.contents());
            exact.append(holder.x()).append('|').append(holder.y()).append('|')
                .append(holder.z()).append('\n');
            for (ItemRef item : holder.items()) {
                exact.append(item.itemId()).append('|')
                    .append(item.parentItemId() == null ? "-" : item.parentItemId())
                    .append('|');
                append(exact, item.fullType());
            }
        }
        return new View(personId, representation, carriedCoverage, worldCoverage,
            digest(exact.toString()), List.copyOf(holders));
    }

    private static View refused(String personId, String representation,
            String reason) {
        return new View(normalizePersonId(personId), representation, "unknown",
            "unknown:" + reason, "", List.of());
    }

    private static String encode(View view) {
        StringBuilder out = new StringBuilder(4096);
        out.append("H|protocol=").append(PROTOCOL)
            .append("|person=").append(field(view.personId()))
            .append("|representation=").append(field(view.representation()))
            .append("|carried=").append(field(view.carriedCoverage()))
            .append("|world=").append(field(view.worldCoverage()))
            .append("|aggregate=refused")
            .append("|revision=").append(field(view.revision())).append('\n');
        for (Holder holder : view.holders()) {
            out.append("R|id=").append(field(holder.id()))
                .append("|kind=").append(field(holder.kind()))
                .append("|x=").append(holder.x())
                .append("|y=").append(holder.y())
                .append("|z=").append(holder.z())
                .append("|access=").append(field(holder.access()))
                .append("|contents=").append(field(holder.contents())).append('\n');
            for (ItemRef item : holder.items()) {
                out.append("I|holder=").append(field(holder.id()))
                    .append("|parent=")
                    .append(item.parentItemId() == null ? "" : item.parentItemId())
                    .append("|id=").append(item.itemId())
                    .append("|type=").append(field(item.fullType())).append('\n');
            }
        }
        out.append("E\n");
        return out.toString();
    }

    private static boolean squareWithinReach(IsoPlayer person,
            IsoGridSquare square) {
        if (person == null || square == null || person.getCell() == null
                || square.getCell() != person.getCell()
                || square.getZ() != (int) person.getZ()) return false;
        IsoGridSquare here = person.getCurrentSquare();
        if (here == null) return false;
        float dx = person.getX() - (square.getX() + 0.5f);
        float dy = person.getY() - (square.getY() + 0.5f);
        return dx * dx + dy * dy <= 4.0f && !here.isSomethingTo(square);
    }

    private static String personId(IsoPlayer person) {
        Object raw = person.getModData().rawget("SAOPersonId");
        return normalizePersonId(raw instanceof String text ? text : "player");
    }

    private static String normalizePersonId(String value) {
        if (value == null || value.isBlank()) return "unknown";
        return value.length() <= 256 ? value : value.substring(0, 256);
    }

    private static void append(StringBuilder out, String value) {
        String present = value(value);
        StringBuilder protectedValue = new StringBuilder(present.length());
        for (int i = 0; i < present.length(); i++) {
            char c = present.charAt(i);
            if (c == '|' || c == ':') {
                protectedValue.append('%');
                protectedValue.append(c == '|' ? "7c" : "3a");
            } else {
                protectedValue.append(c);
            }
        }
        out.append(protectedValue.length()).append((char) 58)
            .append(protectedValue).append((char) 124);
    }

    private static String digest(String value) {
        try {
            byte[] bytes = MessageDigest.getInstance("SHA-256")
                .digest(value.getBytes(StandardCharsets.UTF_8));
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

    private static String field(String value) {
        if (value == null) return "";
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
                    || c == '.' || c == ':') out.append((char) c);
            else {
                out.append('%');
                out.append(Character.forDigit((c >>> 4) & 0xf, 16));
                out.append(Character.forDigit(c & 0xf, 16));
            }
        }
        return out.toString();
    }

    private static String value(String value) {
        return value == null ? "" : value;
    }
}
