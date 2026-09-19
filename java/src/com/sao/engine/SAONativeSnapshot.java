package com.sao.engine;

import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.DataInputStream;
import java.io.DataOutputStream;
import java.io.IOException;
import java.nio.BufferOverflowException;
import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Base64;
import java.util.HashMap;
import java.util.HashSet;
import java.util.IdentityHashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import se.krka.kahlua.vm.KahluaTable;
import zombie.characters.IsoPlayer;
import zombie.characters.IsoGameCharacter;
import zombie.characters.skills.PerkFactory;
import zombie.inventory.InventoryItem;
import zombie.inventory.ItemContainer;
import zombie.inventory.types.InventoryContainer;
import zombie.iso.IsoWorld;
import zombie.scripting.objects.ItemBodyLocation;
import zombie.scripting.objects.ResourceLocation;
import zombie.scripting.objects.Registries;

/**
 * Native component snapshot for an unpublished NPC shell. No player save/load,
 * shell publication, dormant policy, or record ownership changes happen here.
 *
 * Installed Build 42.20 seams: ItemContainer.save/load (source 2725-2755),
 * Stats.save/load, BodyDamage.save/load, IsoGameCharacter.XP.save/load. XP also
 * carries traits, perk levels and multipliers and needs the shell's network AI.
 * ItemContainer serializes nested items; their engine IDs, types and parents
 * are checked after load because the engine may silently drop unknown scripts.
 * Equipment refers to those IDs, never a type's first matching item.
 */
public final class SAONativeSnapshot {
    private static final String PREFIX = "v3;";
    private static final int MAGIC = 0x53414f33;
    private static final int FORMAT = 1;
    private static final int VERIFIED_WORLD_VERSION = 249;
    // Resource bounds, not gameplay policy. Oversize state refuses capture.
    private static final int MAX_BINARY = 16 * 1024 * 1024;
    private static final int MAX_SECTION = 8 * 1024 * 1024;
    private static final int MAX_ITEMS = 32767;
    private static final int MAX_DEPTH = 64;
    private static final int MAX_SLOTS = 1024;
    private static final int DIGEST_BYTES = 32;
    private static final int SECTIONS = 5;

    private SAONativeSnapshot() { }

    @FunctionalInterface
    private interface Writer { void write(ByteBuffer buffer) throws IOException; }

    private record ItemFact(int id, Integer parent, String type) { }
    private record Slot(String location, int item) { }
    private record Equipment(Integer primary, Integer secondary,
                             List<Slot> worn, List<Slot> attached) { }
    private record Manifest(Map<Integer, ItemFact> items, Equipment equipment) { }
    private record Snapshot(int version, byte[][] sections, Manifest manifest) { }

    /** A failed capture throws; callers retain the live person's ownership. */
    public static String capture(IsoPlayer shell) throws IOException {
        requireShell(shell);
        Map<Integer, InventoryItem> items = new LinkedHashMap<>();
        Map<Integer, ItemFact> facts = inventoryFacts(shell.getInventory(), items);
        Equipment equipment = equipment(shell, items);
        byte[][] sections = {
            serialize(buffer -> shell.getInventory().save(buffer)),
            serialize(buffer -> shell.getStats().save(buffer)),
            serialize(buffer -> shell.getBodyDamage().save(buffer)),
            serialize(buffer -> shell.getXp().save(buffer)),
            writeManifest(facts, equipment),
        };
        return encode(sections);
    }

    /** Corpse creation transfers inventory away before a death observer may run. */
    public static String captureReturnLiving(IsoPlayer living) throws IOException {
        requireLiving(living);
        ItemContainer empty = new ItemContainer();
        return encode(new byte[][] {
            serialize(buffer -> empty.save(buffer)),
            serialize(buffer -> living.getStats().save(buffer)),
            serialize(buffer -> living.getBodyDamage().save(buffer)),
            serialize(buffer -> living.getXp().save(buffer)),
            writeManifest(new LinkedHashMap<>(), new Equipment(null, null, List.of(), List.of())),
        });
    }

    /** A turned body supplies current possessions, never living wounds or XP. */
    public static String captureReturn(IsoGameCharacter source, IsoPlayer living) throws IOException {
        requireShell(living);
        if (source == null || source.getInventory() == null) throw new IOException("Missing return source");
        ItemContainer current = returnInventory(source);
        Map<Integer, InventoryItem> items = new LinkedHashMap<>();
        Map<Integer, ItemFact> facts = inventoryFacts(current, items);
        return encode(new byte[][] {
            serialize(buffer -> current.save(buffer)),
            serialize(buffer -> living.getStats().save(buffer)),
            serialize(buffer -> living.getBodyDamage().save(buffer)),
            serialize(buffer -> living.getXp().save(buffer)),
            writeManifest(facts, equipment(source, items)),
        });
    }

    /** Compare all serialized item state before committing a held source. */
    public static boolean returnMaterialsMatch(IsoGameCharacter source, String packed) throws IOException {
        Snapshot snapshot = parse(packed);
        ItemContainer current = returnInventory(source);
        Map<Integer, InventoryItem> items = new LinkedHashMap<>();
        Map<Integer, ItemFact> facts = inventoryFacts(current, items);
        return Arrays.equals(snapshot.sections()[0], serialize(buffer -> current.save(buffer)))
            && Arrays.equals(snapshot.sections()[4], writeManifest(facts, equipment(source, items)));
    }

    // Zombie equipment can exist outside its inventory. A temporary view keeps
    // those actual objects without moving them or generating zombie loot.
    private static ItemContainer returnInventory(IsoGameCharacter source) throws IOException {
        if (!source.isUsingWornItems() && !source.getItemVisuals().isEmpty()) {
            throw new IOException("Visual-only clothing has no transferable item ownership");
        }
        ItemContainer view = new ItemContainer();
        view.getItems().addAll(source.getInventory().getItems());
        List<InventoryItem> equipped = new ArrayList<>();
        equipped.add(source.getPrimaryHandItem());
        equipped.add(source.getSecondaryHandItem());
        for (int i = 0; i < source.getWornItems().size(); i++) equipped.add(source.getWornItems().get(i).getItem());
        for (int i = 0; i < source.getAttachedItems().size(); i++) equipped.add(source.getAttachedItems().get(i).getItem());
        for (InventoryItem item : equipped) {
            if (item == null) continue;
            Map<Integer, InventoryItem> existing = new LinkedHashMap<>();
            inventoryFacts(view, existing);
            if (existing.get(item.id) == item) continue;
            if (existing.containsKey(item.id)) throw new IOException("Conflicting equipment item identity");
            if (item.getContainer() != null && item.getContainer() != source.getInventory()) {
                throw new IOException("Equipment belongs to another inventory");
            }
            view.getItems().add(item);
        }
        return view;
    }

    public static String captureReturnVisual(IsoGameCharacter source) throws IOException {
        if (source == null || source.getVisual() == null) throw new IOException("Missing native visual");
        byte[] bytes = serialize(buffer -> source.getVisual().save(buffer));
        return "1;" + VERIFIED_WORLD_VERSION + ";" + Base64.getEncoder().encodeToString(bytes)
            + ";" + java.util.HexFormat.of().formatHex(hash(bytes));
    }

    public static boolean validateReturnVisual(String packed) {
        try {
            ByteBuffer buffer = ByteBuffer.wrap(returnVisualBytes(packed));
            new zombie.core.skinnedmodel.visual.HumanVisual(null).load(buffer, VERIFIED_WORLD_VERSION);
            consumed(buffer, "return visual");
            return true;
        } catch (IOException | RuntimeException error) { return false; }
    }

    public static void restoreReturnVisual(IsoPlayer destination, String packed) throws IOException {
        byte[] bytes = returnVisualBytes(packed);
        // Validate the native payload on an unowned visual before changing a body.
        ByteBuffer check = ByteBuffer.wrap(bytes);
        new zombie.core.skinnedmodel.visual.HumanVisual(null).load(check, VERIFIED_WORLD_VERSION);
        consumed(check, "return visual");
        ByteBuffer buffer = ByteBuffer.wrap(bytes);
        destination.getVisual().load(buffer, VERIFIED_WORLD_VERSION);
        consumed(buffer, "return visual");
    }

    private static byte[] returnVisualBytes(String packed) throws IOException {
        if (packed == null || packed.length() > MAX_SECTION * 2) throw new IOException("Missing return visual");
        String[] parts = packed.split(";", -1);
        if (parts.length != 4 || !parts[0].equals("1")
                || !parts[1].equals(Integer.toString(VERIFIED_WORLD_VERSION))
                || IsoWorld.getWorldVersion() != VERIFIED_WORLD_VERSION) {
            throw new IOException("Unsupported return visual version");
        }
        byte[] bytes;
        try { bytes = Base64.getDecoder().decode(parts[2]); }
        catch (IllegalArgumentException error) { throw new IOException("Invalid return visual", error); }
        if (!java.util.HexFormat.of().formatHex(hash(bytes)).equals(parts[3])) {
            throw new IOException("Return visual checksum mismatch");
        }
        return bytes;
    }

    private static String encode(byte[][] sections) throws IOException {
        ByteArrayOutputStream bytes = new ByteArrayOutputStream();
        try (DataOutputStream out = new DataOutputStream(bytes)) {
            out.writeInt(MAGIC);
            out.writeInt(FORMAT);
            out.writeInt(VERIFIED_WORLD_VERSION);
            out.writeInt(SECTIONS);
            for (byte[] section : sections) {
                if (bytes.size() + 4L + section.length + DIGEST_BYTES > MAX_BINARY) {
                    throw new IOException("Snapshot exceeds total size limit");
                }
                out.writeInt(section.length);
                out.write(section);
            }
            out.flush();
            out.write(hash(bytes.toByteArray()));
        }
        String packed = PREFIX + Base64.getEncoder().encodeToString(bytes.toByteArray());
        parse(packed);
        return packed;
    }

    /** Structural/version/integrity check only: no item creation or body mutation. */
    public static boolean validate(String packed) {
        try {
            parse(packed);
            return true;
        } catch (IOException | RuntimeException error) {
            return false;
        }
    }

    /**
     * Restore onto a fresh, unpublished shell. On any exception the caller must
     * discard that partial shell and keep the durable snapshot for retry.
     * Returns the total number of restored items, including nested contents.
     */
    public static int restore(IsoPlayer shell, String packed) throws IOException {
        return restore(shell, packed, true);
    }

    public static int restoreStaged(IsoPlayer shell, String packed) throws IOException {
        return restore(shell, packed, false);
    }

    private static int restore(IsoPlayer shell, String packed, boolean registerItems) throws IOException {
        requireShell(shell);
        Snapshot snapshot = parse(packed);
        byte[][] sections = snapshot.sections();
        ItemContainer inventory = new ItemContainer();
        ByteBuffer buffer = ByteBuffer.wrap(sections[0]);
        ArrayList<InventoryItem> loaded = inventory.load(buffer, snapshot.version());
        consumed(buffer, "inventory");
        if (loaded == null || loaded.contains(null)) {
            throw new IOException("Native inventory load dropped an item");
        }
        Map<Integer, InventoryItem> items = new LinkedHashMap<>();
        Map<Integer, ItemFact> facts = inventoryFacts(inventory, items);
        if (!facts.equals(snapshot.manifest().items())) {
            throw new IOException("Restored item identity/type/container differs");
        }
        Equipment equipment = snapshot.manifest().equipment();
        checkLocations(shell, equipment);

        // Component restore can throw; none of these publish the new shell.
        buffer = ByteBuffer.wrap(sections[1]);
        shell.getStats().load(buffer, snapshot.version());
        consumed(buffer, "stats");
        buffer = ByteBuffer.wrap(sections[2]);
        shell.getBodyDamage().load(buffer, snapshot.version());
        consumed(buffer, "body damage");
        buffer = ByteBuffer.wrap(sections[3]);
        shell.getXp().load(buffer, snapshot.version());
        consumed(buffer, "experience");

        shell.setPrimaryHandItem(null);
        shell.setSecondaryHandItem(null);
        shell.clearWornItems();
        shell.clearAttachedItems();
        shell.setInventory(inventory);
        for (Slot slot : equipment.worn()) {
            if (registerItems) shell.setWornItem(bodyLocation(slot.location()), items.get(slot.item()));
            else shell.getWornItems().setItem(bodyLocation(slot.location()), items.get(slot.item()));
        }
        for (Slot slot : equipment.attached()) {
            if (registerItems) shell.setAttachedItem(slot.location(), items.get(slot.item()));
            else shell.getAttachedItems().setItem(slot.location(), items.get(slot.item()));
        }
        shell.setPrimaryHandItem(item(items, equipment.primary()));
        shell.setSecondaryHandItem(item(items, equipment.secondary()));
        if (!equipment.equals(equipment(shell, items))) {
            throw new IOException("Equipment restoration did not preserve references");
        }
        shell.resetModelNextFrame();
        // Native load/setInventory do not register unequipped or nested items.
        // Use the engine's idempotent registration after every restore check;
        // Food is processed by the cell, not the character's IUpdater walk.
        if (registerItems && IsoWorld.instance.currentCell != null) {
            for (InventoryItem restored : items.values()) {
                IsoWorld.instance.currentCell.addToProcessItems(restored);
            }
        }
        return items.size();
    }

    public static void register(IsoPlayer shell) throws IOException {
        Map<Integer, InventoryItem> items = new LinkedHashMap<>();
        inventoryFacts(shell.getInventory(), items);
        if (IsoWorld.instance.currentCell != null) {
            for (InventoryItem carried : items.values()) {
                IsoWorld.instance.currentCell.addToProcessItems(carried);
            }
        }
    }

    /** Detach every carried item from native processing when its shell leaves. */
    public static void unregister(IsoPlayer shell) throws IOException {
        if (shell == null || shell.getInventory() == null) {
            throw new IOException("Missing inventory for native processing removal");
        }
        Map<Integer, InventoryItem> items = new LinkedHashMap<>();
        inventoryFacts(shell.getInventory(), items);
        if (IsoWorld.instance.currentCell != null) {
            for (InventoryItem carried : items.values()) {
                IsoWorld.instance.currentCell.addToProcessItemsRemove(carried);
            }
        }
    }

    // World version 249 XP.save writes native trait names, three scalar fields,
    // then name/value maps for earned XP, perk levels and reading multipliers.
    // XP.load silently skips unavailable perks. Check registry names without
    // loading a component, so a missing mod refuses the handoff before teardown.
    private static void checkExperience(byte[] bytes) throws IOException {
        ByteBuffer input = ByteBuffer.wrap(bytes);
        int traits = bounded(input.getInt(), MAX_ITEMS, "trait count");
        for (int i = 0; i < traits; i++) {
            String name = zombie.GameWindow.ReadString(input);
            text(name);
            if (!Registries.CHARACTER_TRAIT.contains(ResourceLocation.of(name))) {
                throw new IOException("Native trait unavailable: " + name);
            }
        }
        if (!Float.isFinite(input.getFloat())) throw new IOException("Nonfinite total XP");
        input.getInt(); // level
        input.getInt(); // last level
        for (int channel = 0; channel < 3; channel++) {
            int count = bounded(input.getInt(), MAX_ITEMS, "perk count");
            Set<String> names = new HashSet<>();
            for (int i = 0; i < count; i++) {
                String name = zombie.GameWindow.ReadString(input);
                text(name);
                PerkFactory.Perk perk = PerkFactory.Perks.FromString(name);
                if (perk == null || perk == PerkFactory.Perks.MAX || !name.equals(perk.getId())) {
                    throw new IOException("Native perk unavailable: " + name);
                }
                if (!names.add(name)) throw new IOException("Duplicate native perk: " + name);
                if (channel == 1) {
                    input.getInt(); // perk level
                } else {
                    if (!Float.isFinite(input.getFloat())) throw new IOException("Nonfinite perk value");
                    if (channel == 2) { input.get(); input.get(); } // multiplier level range
                }
            }
        }
        consumed(input, "native experience preflight");
    }

    private static void requireShell(IsoPlayer shell) throws IOException {
        requireLiving(shell);
        if (shell.getInventory() == null || shell.getWornItems() == null || shell.getAttachedItems() == null) {
            throw new IOException("Incomplete native material components");
        }
    }

    private static void requireLiving(IsoPlayer shell) throws IOException {
        if (IsoWorld.getWorldVersion() != VERIFIED_WORLD_VERSION) {
            throw new IOException("Unsupported engine snapshot version");
        }
        if (shell == null || shell.getStats() == null
                || shell.getBodyDamage() == null || shell.getXp() == null
                || shell.getNetworkCharacterAI() == null) {
            throw new IOException("Incomplete native person components");
        }
    }

    private static byte[] serialize(Writer writer) throws IOException {
        int capacity = 16384;
        while (true) {
            ByteBuffer buffer = ByteBuffer.allocate(capacity);
            try {
                writer.write(buffer);
                return Arrays.copyOf(buffer.array(), buffer.position());
            } catch (BufferOverflowException tooSmall) {
                if (capacity >= MAX_SECTION) {
                    throw new IOException("Native component exceeds size limit", tooSmall);
                }
                capacity = Math.min(MAX_SECTION, capacity * 2);
            }
        }
    }

    private static Map<Integer, ItemFact> inventoryFacts(ItemContainer container,
            Map<Integer, InventoryItem> items) throws IOException {
        Map<Integer, ItemFact> facts = new LinkedHashMap<>();
        collect(container, null, 0, items, facts, new IdentityHashMap<>());
        return facts;
    }

    private static void collect(ItemContainer container, Integer parent, int depth,
            Map<Integer, InventoryItem> items, Map<Integer, ItemFact> facts,
            IdentityHashMap<InventoryItem, Boolean> seen) throws IOException {
        if (depth > MAX_DEPTH || container == null) {
            throw new IOException("Invalid nested inventory");
        }
        for (InventoryItem item : container.getItems()) {
            if (item == null || seen.put(item, Boolean.TRUE) != null
                    || items.containsKey(item.id) || items.size() >= MAX_ITEMS) {
                throw new IOException("Duplicate, cyclic, null or excessive inventory item");
            }
            text(item.getFullType());
            if (item.hasModData()) checkNativeTable(item.getModData(), 0, new IdentityHashMap<>());
            items.put(item.id, item);
            facts.put(item.id, new ItemFact(item.id, parent, item.getFullType()));
            if (item instanceof InventoryContainer nested) {
                collect(nested.getInventory(), item.id, depth + 1, items, facts, seen);
            }
        }
    }

    // Native Kahlua strings use a signed-short UTF-8 byte length. A larger
    // value can shift the item reader into subsequent fields without throwing.
    // Outer snapshot fragmentation cannot repair bytes already lost here.
    private static void checkNativeTable(Object value, int depth,
            IdentityHashMap<KahluaTable, Boolean> visiting) throws IOException {
        if (value instanceof String text) {
            if (text.getBytes(StandardCharsets.UTF_8).length > 32767)
                throw new IOException("Item ModData string exceeds native byte limit");
        } else if (value instanceof KahluaTable table) {
            if (depth > MAX_DEPTH || visiting.put(table, Boolean.TRUE) != null)
                throw new IOException("Cyclic or excessive item ModData depth");
            var iterator = table.iterator();
            while (iterator.advance()) {
                checkNativeTable(iterator.getKey(), depth + 1, visiting);
                checkNativeTable(iterator.getValue(), depth + 1, visiting);
            }
            visiting.remove(table);
        }
    }

    private static Equipment equipment(IsoGameCharacter shell, Map<Integer, InventoryItem> items)
            throws IOException {
        List<Slot> worn = new ArrayList<>();
        for (int i = 0; i < shell.getWornItems().size(); i++) {
            var entry = shell.getWornItems().get(i);
            worn.add(new Slot(entry.getLocation().toString(), reference(items, entry.getItem())));
        }
        List<Slot> attached = new ArrayList<>();
        for (int i = 0; i < shell.getAttachedItems().size(); i++) {
            var entry = shell.getAttachedItems().get(i);
            attached.add(new Slot(entry.getLocation(), reference(items, entry.getItem())));
        }
        // Locations define equipment, independent of the engine list order.
        worn.sort(java.util.Comparator.comparing(Slot::location).thenComparingInt(Slot::item));
        attached.sort(java.util.Comparator.comparing(Slot::location).thenComparingInt(Slot::item));
        return new Equipment(reference(items, shell.getPrimaryHandItem()),
                reference(items, shell.getSecondaryHandItem()), worn, attached);
    }

    private static Integer reference(Map<Integer, InventoryItem> items, InventoryItem item)
            throws IOException {
        if (item == null) return null;
        if (items.get(item.id) != item) throw new IOException("Equipment outside inventory");
        return item.id;
    }

    private static InventoryItem item(Map<Integer, InventoryItem> items, Integer id) {
        return id == null ? null : items.get(id);
    }

    private static byte[] writeManifest(Map<Integer, ItemFact> items, Equipment equipment)
            throws IOException {
        ByteArrayOutputStream bytes = new ByteArrayOutputStream();
        try (DataOutputStream out = new DataOutputStream(bytes)) {
            out.writeInt(items.size());
            for (ItemFact fact : items.values()) {
                out.writeInt(fact.id());
                writeReference(out, fact.parent());
                out.writeUTF(fact.type());
            }
            writeReference(out, equipment.primary());
            writeReference(out, equipment.secondary());
            for (List<Slot> slots : List.of(equipment.worn(), equipment.attached())) {
                if (slots.size() > MAX_SLOTS) throw new IOException("Too many equipment slots");
                out.writeInt(slots.size());
                for (Slot slot : slots) {
                    text(slot.location());
                    out.writeUTF(slot.location());
                    out.writeInt(slot.item());
                }
            }
        }
        return bytes.toByteArray();
    }

    private static void writeReference(DataOutputStream out, Integer id) throws IOException {
        out.writeBoolean(id != null);
        if (id != null) out.writeInt(id);
    }

    private static Integer readReference(DataInputStream in) throws IOException {
        int present = in.readUnsignedByte();
        if (present > 1) throw new IOException("Invalid optional item reference");
        return present == 0 ? null : in.readInt();
    }

    private static Manifest readManifest(byte[] bytes) throws IOException {
        try (DataInputStream in = new DataInputStream(new ByteArrayInputStream(bytes))) {
            int count = bounded(in.readInt(), MAX_ITEMS, "item count");
            Map<Integer, ItemFact> items = new HashMap<>();
            for (int i = 0; i < count; i++) {
                int id = in.readInt();
                Integer parent = readReference(in);
                String type = in.readUTF();
                text(type);
                if (items.put(id, new ItemFact(id, parent, type)) != null) {
                    throw new IOException("Duplicate manifest identity");
                }
            }
            for (ItemFact fact : items.values()) {
                Set<Integer> ancestors = new HashSet<>();
                Integer parent = fact.parent();
                while (parent != null) {
                    if (!items.containsKey(parent) || parent == fact.id()
                            || !ancestors.add(parent) || ancestors.size() > MAX_DEPTH) {
                        throw new IOException("Invalid manifest parent chain");
                    }
                    parent = items.get(parent).parent();
                }
            }
            Integer primary = readReference(in), secondary = readReference(in);
            checkReference(items, primary);
            checkReference(items, secondary);
            List<Slot> worn = readSlots(in, items), attached = readSlots(in, items);
            if (in.available() != 0) throw new IOException("Trailing manifest data");
            return new Manifest(items, new Equipment(primary, secondary, worn, attached));
        }
    }

    private static List<Slot> readSlots(DataInputStream in, Map<Integer, ItemFact> items)
            throws IOException {
        int count = bounded(in.readInt(), MAX_SLOTS, "equipment count");
        List<Slot> slots = new ArrayList<>();
        Set<Slot> seen = new HashSet<>();
        for (int i = 0; i < count; i++) {
            String location = in.readUTF();
            text(location);
            int id = in.readInt();
            checkReference(items, id);
            Slot slot = new Slot(location, id);
            if (!seen.add(slot)) throw new IOException("Duplicate equipment reference");
            slots.add(slot);
        }
        slots.sort(java.util.Comparator.comparing(Slot::location).thenComparingInt(Slot::item));
        return slots;
    }

    private static void checkReference(Map<Integer, ItemFact> items, Integer id)
            throws IOException {
        if (id != null && !items.containsKey(id)) throw new IOException("Missing item reference");
    }

    private static ItemBodyLocation bodyLocation(String name) throws IOException {
        ItemBodyLocation location = ItemBodyLocation.get(ResourceLocation.of(name));
        if (location == null) throw new IOException("Unknown body location: " + name);
        return location;
    }

    private static void checkLocations(IsoPlayer shell, Equipment equipment) throws IOException {
        for (Slot slot : equipment.worn()) {
            if (shell.getWornItems().getBodyLocationGroup()
                    .getLocation(bodyLocation(slot.location())) == null) {
                throw new IOException("Unavailable worn location: " + slot.location());
            }
        }
        for (Slot slot : equipment.attached()) {
            if (shell.getAttachedItems().getGroup().getLocation(slot.location()) == null) {
                throw new IOException("Unavailable attached location: " + slot.location());
            }
        }
    }

    private static Snapshot parse(String packed) throws IOException {
        if (packed == null || !packed.startsWith(PREFIX)
                || packed.length() > PREFIX.length() + 4L * ((MAX_BINARY + 2) / 3)) {
            throw new IOException("Invalid snapshot encoding or size");
        }
        byte[] bytes;
        try {
            bytes = Base64.getDecoder().decode(packed.substring(PREFIX.length()));
        } catch (IllegalArgumentException error) {
            throw new IOException("Invalid snapshot Base64", error);
        }
        if (bytes.length < 16 + SECTIONS * 4 + DIGEST_BYTES || bytes.length > MAX_BINARY) {
            throw new IOException("Invalid snapshot length");
        }
        int payloadSize = bytes.length - DIGEST_BYTES;
        if (!MessageDigest.isEqual(hash(Arrays.copyOf(bytes, payloadSize)),
                Arrays.copyOfRange(bytes, payloadSize, bytes.length))) {
            throw new IOException("Snapshot checksum mismatch");
        }
        try (DataInputStream in = new DataInputStream(
                new ByteArrayInputStream(bytes, 0, payloadSize))) {
            if (in.readInt() != MAGIC || in.readInt() != FORMAT) {
                throw new IOException("Unsupported snapshot format");
            }
            int version = in.readInt();
            if (version != VERIFIED_WORLD_VERSION || IsoWorld.getWorldVersion() != version) {
                throw new IOException("Unsupported engine snapshot version");
            }
            if (in.readInt() != SECTIONS) throw new IOException("Invalid component count");
            byte[][] sections = new byte[SECTIONS][];
            for (int i = 0; i < SECTIONS; i++) {
                int size = bounded(in.readInt(), MAX_SECTION, "component size");
                if (size == 0 || size > in.available()) throw new IOException("Truncated component");
                sections[i] = in.readNBytes(size);
            }
            if (in.available() != 0) throw new IOException("Trailing snapshot data");
            if (sections[1].length != zombie.characters.CharacterStat.ORDERED_STATS.length * 4) {
                throw new IOException("Unexpected native stat layout");
            }
            checkExperience(sections[3]);
            return new Snapshot(version, sections, readManifest(sections[4]));
        }
    }

    private static int bounded(int value, int limit, String name) throws IOException {
        if (value < 0 || value > limit) throw new IOException("Invalid " + name);
        return value;
    }

    private static void text(String value) throws IOException {
        if (value == null || value.isEmpty() || value.length() > 4096) {
            throw new IOException("Invalid snapshot identifier");
        }
    }

    private static void consumed(ByteBuffer buffer, String name) throws IOException {
        if (buffer.hasRemaining()) throw new IOException("Unread native " + name + " data");
    }

    private static byte[] hash(byte[] value) {
        try {
            return MessageDigest.getInstance("SHA-256").digest(value);
        } catch (NoSuchAlgorithmException impossible) {
            throw new IllegalStateException(impossible);
        }
    }
}
