package com.sao.engine;

import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.DataInputStream;
import java.io.DataOutputStream;
import java.io.IOException;
import java.lang.reflect.Field;
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
import java.util.TreeMap;
import se.krka.kahlua.vm.KahluaTable;
import se.krka.kahlua.j2se.KahluaTableImpl;
import zombie.characters.IsoPlayer;
import zombie.characters.IsoGameCharacter;
import zombie.characters.BodyDamage.Fitness;
import zombie.characters.BodyDamage.Nutrition;
import zombie.characters.skills.PerkFactory;
import zombie.core.skinnedmodel.population.Outfit;
import zombie.core.skinnedmodel.population.OutfitManager;
import zombie.core.skinnedmodel.visual.HumanVisual;
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
    private static final String PREFIX_V3 = "v3;";
    private static final String PREFIX_V4 = "v4;";
    private static final int MAGIC_V3 = 0x53414f33;
    private static final int MAGIC_V4 = 0x53414f34;
    private static final int FORMAT = 1;
    private static final int VERIFIED_WORLD_VERSION = 249;
    // Resource bounds, not gameplay policy. Oversize state refuses capture.
    private static final int MAX_BINARY = 16 * 1024 * 1024;
    private static final int MAX_SECTION = 8 * 1024 * 1024;
    private static final int MAX_ITEMS = 32767;
    private static final int MAX_DEPTH = 64;
    private static final int MAX_SLOTS = 1024;
    private static final int DIGEST_BYTES = 32;
    private static final int SECTIONS_V3 = 5;
    private static final int SECTIONS_V4 = 10;
    private static final Set<String> RUNTIME_MODDATA = Set.of(
        "SAOPersonId", "SAOReturnToken", "SAOReturnReady", "ZAOForm",
        "ZAOFormPerformance", "ZAOAttributes", "ZAOTerminalState", "ZAODormantKnox");

    private SAONativeSnapshot() { }

    @FunctionalInterface
    private interface Writer { void write(ByteBuffer buffer) throws IOException; }

    private record ItemFact(int id, Integer parent, String type) { }
    private record Slot(String location, int item) { }
    private record Equipment(Integer primary, Integer secondary,
                             List<Slot> worn, List<Slot> attached) { }
    private record Manifest(Map<Integer, ItemFact> items, Equipment equipment,
                            Map<Integer, byte[]> fluids) { }
    private record Snapshot(int schema, int version, byte[][] sections, Manifest manifest) { }
    private record VisualState(byte[] nativeVisual, String outfit, String forceModelScript,
                               float beardGrowTiming, float hairGrowTiming) { }
    private record LearningState(List<String> recipes, List<String> mediaLines,
                                 Map<String, Integer> readBooks, List<String> completedBooks,
                                 Map<String, Integer> literature, List<String> printMedia,
                                 Map<String, Integer> boosts) { }

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
            writeManifest(facts, equipment, fluidFacts(items)),
            writeNutrition(shell.getNutrition()),
            serialize(buffer -> shell.getFitness().save(buffer)),
            writeLearning(shell),
            writeVisual(shell.getHumanVisual(), shell),
            writeCharacterModData(shell),
        };
        return encode(4, sections);
    }

    /** Corpse creation transfers inventory away before a death observer may run. */
    public static String captureReturnLiving(IsoPlayer living) throws IOException {
        requireLiving(living);
        ItemContainer empty = new ItemContainer();
        return encode(4, new byte[][] {
            serialize(buffer -> empty.save(buffer)),
            serialize(buffer -> living.getStats().save(buffer)),
            serialize(buffer -> living.getBodyDamage().save(buffer)),
            serialize(buffer -> living.getXp().save(buffer)),
            writeManifest(new LinkedHashMap<>(), new Equipment(null, null, List.of(), List.of()),
                new LinkedHashMap<>()),
            writeNutrition(living.getNutrition()),
            serialize(buffer -> living.getFitness().save(buffer)),
            writeLearning(living),
            writeVisual(living.getHumanVisual(), living),
            writeCharacterModData(living),
        });
    }

    /** A turned body supplies current possessions, never living wounds or XP. */
    public static String captureReturn(IsoGameCharacter source, IsoPlayer living) throws IOException {
        requireShell(living);
        if (source == null || source.getInventory() == null) throw new IOException("Missing return source");
        ItemContainer current = returnInventory(source);
        Map<Integer, InventoryItem> items = new LinkedHashMap<>();
        Map<Integer, ItemFact> facts = inventoryFacts(current, items);
        return encode(4, new byte[][] {
            serialize(buffer -> current.save(buffer)),
            serialize(buffer -> living.getStats().save(buffer)),
            serialize(buffer -> living.getBodyDamage().save(buffer)),
            serialize(buffer -> living.getXp().save(buffer)),
            writeManifest(facts, equipment(source, items), fluidFacts(items)),
            writeNutrition(living.getNutrition()),
            serialize(buffer -> living.getFitness().save(buffer)),
            writeLearning(living),
            writeVisual(humanVisual(source), source),
            writeCharacterModData(living),
        });
    }

    /** Compare all serialized item state before committing a held source. */
    public static boolean returnMaterialsMatch(IsoGameCharacter source, String packed) throws IOException {
        Snapshot snapshot = parse(packed);
        ItemContainer current = returnInventory(source);
        Map<Integer, InventoryItem> items = new LinkedHashMap<>();
        Map<Integer, ItemFact> facts = inventoryFacts(current, items);
        return Arrays.equals(snapshot.sections()[0], serialize(buffer -> current.save(buffer)))
            && Arrays.equals(snapshot.sections()[4], writeManifest(facts, equipment(source, items),
                fluidFacts(items)));
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

    public static boolean isNative(String packed) {
        return packed != null && (packed.startsWith(PREFIX_V3) || packed.startsWith(PREFIX_V4));
    }

    public static int formatVersion(String packed) throws IOException {
        return parse(packed).schema();
    }

    private static String encode(int schema, byte[][] sections) throws IOException {
        int count = schema == 4 ? SECTIONS_V4 : SECTIONS_V3;
        if (sections.length != count) throw new IOException("Invalid component count");
        ByteArrayOutputStream bytes = new ByteArrayOutputStream();
        try (DataOutputStream out = new DataOutputStream(bytes)) {
            out.writeInt(schema == 4 ? MAGIC_V4 : MAGIC_V3);
            out.writeInt(FORMAT);
            out.writeInt(VERIFIED_WORLD_VERSION);
            out.writeInt(count);
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
        String packed = (schema == 4 ? PREFIX_V4 : PREFIX_V3)
            + Base64.getEncoder().encodeToString(bytes.toByteArray());
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
        checkFluidFacts(items, snapshot.manifest().fluids());
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

        if (snapshot.schema() >= 4) {
            restoreNutrition(shell.getNutrition(), sections[5]);
            Fitness fitness = new Fitness(shell);
            buffer = ByteBuffer.wrap(sections[6]);
            fitness.load(buffer, snapshot.version());
            consumed(buffer, "fitness");
            // Load before init: init supplies exercise definitions, while its
            // profession defaults leave a nonempty restored regularity map alone.
            fitness.init();
            setField(shell, IsoPlayer.class, "fitness", fitness);
            restoreLearning(shell, sections[7]);
            restoreCharacterModData(shell, sections[9]);
        }

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
        if (snapshot.schema() >= 4) restoreVisual(shell, sections[8]);
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
                || shell.getNetworkCharacterAI() == null || shell.getNutrition() == null
                || shell.getFitness() == null || shell.getHumanVisual() == null
                || shell.getDescriptor() == null || shell.getModData() == null) {
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
                if (!KahluaTableImpl.canSave(iterator.getKey(), iterator.getValue())) {
                    throw new IOException("Unsupported native ModData value");
                }
                checkNativeTable(iterator.getKey(), depth + 1, visiting);
                checkNativeTable(iterator.getValue(), depth + 1, visiting);
            }
            visiting.remove(table);
        }
    }

    private static byte[] writeNutrition(Nutrition nutrition) throws IOException {
        byte[] nativeState = serialize(buffer -> nutrition.save(buffer));
        if (nativeState.length != 20) throw new IOException("Unexpected native nutrition layout");
        checkNutritionNative(nativeState);
        ByteArrayOutputStream bytes = new ByteArrayOutputStream();
        try (DataOutputStream out = new DataOutputStream(bytes)) {
            out.write(nativeState);
            out.writeInt((Integer) getField(nutrition, Nutrition.class, "updatedWeight"));
            float maximum = (Float) getField(nutrition, Nutrition.class, "caloriesMax");
            float minimum = (Float) getField(nutrition, Nutrition.class, "caloriesMin");
            if (!Float.isFinite(maximum) || !Float.isFinite(minimum)) {
                throw new IOException("Nonfinite nutrition extrema");
            }
            out.writeFloat(maximum);
            out.writeFloat(minimum);
            out.writeBoolean(nutrition.isIncWeight());
            out.writeBoolean(nutrition.isIncWeightLot());
            out.writeBoolean(nutrition.isDecWeight());
        }
        return bytes.toByteArray();
    }

    private static void checkNutritionNative(byte[] bytes) throws IOException {
        if (bytes.length < 20) throw new IOException("Truncated native nutrition");
        ByteBuffer input = ByteBuffer.wrap(bytes, 0, 20);
        for (int i = 0; i < 4; i++) {
            if (!Float.isFinite(input.getFloat())) throw new IOException("Nonfinite nutrition value");
        }
        float weight = input.getFloat();
        // Nutrition.load calls setWeight, whose below-floor path causes damage and an event.
        if (!Float.isFinite(weight) || weight < 35.0f || weight > 1000.0f) {
            throw new IOException("Unsafe nutrition weight");
        }
    }

    private static void checkNutrition(byte[] bytes) throws IOException {
        if (bytes.length != 35) throw new IOException("Unexpected nutrition extension layout");
        checkNutritionNative(bytes);
        try (DataInputStream in = new DataInputStream(new ByteArrayInputStream(bytes, 20, 15))) {
            in.readInt();
            if (!Float.isFinite(in.readFloat()) || !Float.isFinite(in.readFloat())) {
                throw new IOException("Nonfinite nutrition extrema");
            }
            for (int i = 0; i < 3; i++) {
                int flag = in.readUnsignedByte();
                if (flag > 1) throw new IOException("Invalid nutrition flag");
            }
            if (in.available() != 0) throw new IOException("Trailing nutrition data");
        }
    }

    private static void restoreNutrition(Nutrition nutrition, byte[] bytes) throws IOException {
        checkNutrition(bytes);
        ByteBuffer nativeState = ByteBuffer.wrap(bytes, 0, 20).slice();
        nutrition.load(nativeState);
        consumed(nativeState, "nutrition");
        try (DataInputStream in = new DataInputStream(new ByteArrayInputStream(bytes, 20, 15))) {
            setField(nutrition, Nutrition.class, "updatedWeight", in.readInt());
            setField(nutrition, Nutrition.class, "caloriesMax", in.readFloat());
            setField(nutrition, Nutrition.class, "caloriesMin", in.readFloat());
            nutrition.setIncWeight(in.readBoolean());
            nutrition.setIncWeightLot(in.readBoolean());
            nutrition.setDecWeight(in.readBoolean());
        }
    }

    private static void checkFitness(byte[] bytes) throws IOException {
        ByteBuffer input = ByteBuffer.wrap(bytes);
        checkFitnessMap(input, 4, true, "stiffness increment");
        checkFitnessMap(input, 4, false, "stiffness timer");
        checkFitnessMap(input, 4, true, "exercise regularity");
        int affected = bounded(input.getInt(), MAX_ITEMS, "fitness body-part count");
        Set<String> seen = new HashSet<>();
        for (int i = 0; i < affected; i++) {
            String name = zombie.GameWindow.ReadString(input);
            text(name);
            if (!seen.add(name)) throw new IOException("Duplicate fitness body part");
        }
        checkFitnessMap(input, 8, false, "exercise timestamp");
        consumed(input, "fitness preflight");
    }

    private static void checkFitnessMap(ByteBuffer input, int valueBytes, boolean floating,
            String name) throws IOException {
        int count = bounded(input.getInt(), MAX_ITEMS, name + " count");
        Set<String> seen = new HashSet<>();
        for (int i = 0; i < count; i++) {
            String key = zombie.GameWindow.ReadString(input);
            text(key);
            if (!seen.add(key)) throw new IOException("Duplicate " + name);
            if (floating) {
                if (!Float.isFinite(input.getFloat())) throw new IOException("Nonfinite " + name);
            } else if (valueBytes == 8) input.getLong();
            else input.getInt();
        }
    }

    @SuppressWarnings("unchecked")
    private static byte[] writeLearning(IsoPlayer shell) throws IOException {
        ByteArrayOutputStream bytes = new ByteArrayOutputStream();
        try (DataOutputStream out = new DataOutputStream(bytes)) {
            writeStringList(out, new ArrayList<>(shell.getKnownRecipes()));
            Set<String> media = (Set<String>) getField(shell, IsoGameCharacter.class, "knownMediaLines");
            writeStringList(out, sorted(media));
            List<Object> books = (List<Object>) getField(shell, IsoGameCharacter.class, "readBooks");
            if (books.size() > MAX_ITEMS) throw new IOException("Too many read books");
            out.writeInt(books.size());
            for (Object book : books) {
                String type = (String) getField(book, book.getClass(), "fullType");
                int pages = (Integer) getField(book, book.getClass(), "alreadyReadPages");
                text(type);
                if (pages < 0) throw new IOException("Negative read-page count");
                out.writeUTF(type);
                out.writeInt(pages);
            }
            writeStringList(out, new ArrayList<>(shell.getAlreadyReadBook()));
            writeStringIntMap(out, shell.getReadLiterature());
            writeStringList(out, sorted(shell.getReadPrintMedia()));
            Map<String, Integer> boosts = new TreeMap<>();
            for (Map.Entry<PerkFactory.Perk, Integer> entry
                    : shell.getDescriptor().getXPBoostMap().entrySet()) {
                if (entry.getKey() == null || entry.getValue() == null) {
                    throw new IOException("Invalid descriptor perk boost");
                }
                boosts.put(entry.getKey().getId(), entry.getValue());
            }
            writeStringIntMap(out, boosts);
        }
        return bytes.toByteArray();
    }

    private static LearningState readLearning(byte[] bytes) throws IOException {
        try (DataInputStream in = new DataInputStream(new ByteArrayInputStream(bytes))) {
            List<String> recipes = readStringList(in, "known recipe");
            List<String> media = readStringList(in, "known media line");
            int count = bounded(in.readInt(), MAX_ITEMS, "read-book count");
            Map<String, Integer> books = new LinkedHashMap<>();
            for (int i = 0; i < count; i++) {
                String type = in.readUTF();
                text(type);
                int pages = in.readInt();
                if (pages < 0 || books.put(type, pages) != null) {
                    throw new IOException("Invalid read-book progress");
                }
            }
            List<String> completed = readStringList(in, "completed book");
            Map<String, Integer> literature = readStringIntMap(in, "read literature");
            List<String> print = readStringList(in, "read print media");
            Map<String, Integer> boosts = readStringIntMap(in, "descriptor perk boost");
            for (String id : boosts.keySet()) requirePerk(id);
            if (in.available() != 0) throw new IOException("Trailing learning data");
            return new LearningState(recipes, media, books, completed, literature, print, boosts);
        }
    }

    @SuppressWarnings("unchecked")
    private static void restoreLearning(IsoPlayer shell, byte[] bytes) throws IOException {
        LearningState state = readLearning(bytes);
        shell.getKnownRecipes().clear();
        shell.getKnownRecipes().addAll(state.recipes());
        Set<String> media = (Set<String>) getField(shell, IsoGameCharacter.class, "knownMediaLines");
        media.clear();
        media.addAll(state.mediaLines());
        List<Object> books = (List<Object>) getField(shell, IsoGameCharacter.class, "readBooks");
        books.clear();
        for (Map.Entry<String, Integer> entry : state.readBooks().entrySet()) {
            shell.setAlreadyReadPages(entry.getKey(), entry.getValue());
        }
        shell.getAlreadyReadBook().clear();
        shell.getAlreadyReadBook().addAll(state.completedBooks());
        shell.getReadLiterature().clear();
        shell.getReadLiterature().putAll(state.literature());
        shell.getReadPrintMedia().clear();
        shell.getReadPrintMedia().addAll(state.printMedia());
        shell.getDescriptor().getXPBoostMap().clear();
        for (Map.Entry<String, Integer> entry : state.boosts().entrySet()) {
            shell.getDescriptor().getXPBoostMap().put(requirePerk(entry.getKey()), entry.getValue());
        }
    }

    private static void writeStringList(DataOutputStream out, List<String> values) throws IOException {
        if (values.size() > MAX_ITEMS) throw new IOException("Too many learning values");
        out.writeInt(values.size());
        for (String value : values) {
            text(value);
            out.writeUTF(value);
        }
    }

    private static List<String> readStringList(DataInputStream in, String name) throws IOException {
        int count = bounded(in.readInt(), MAX_ITEMS, name + " count");
        List<String> values = new ArrayList<>();
        Set<String> seen = new HashSet<>();
        for (int i = 0; i < count; i++) {
            String value = in.readUTF();
            text(value);
            if (!seen.add(value)) throw new IOException("Duplicate " + name);
            values.add(value);
        }
        return values;
    }

    private static void writeStringIntMap(DataOutputStream out, Map<String, Integer> values)
            throws IOException {
        if (values.size() > MAX_ITEMS) throw new IOException("Too many learning values");
        out.writeInt(values.size());
        for (Map.Entry<String, Integer> entry : new TreeMap<>(values).entrySet()) {
            text(entry.getKey());
            if (entry.getValue() == null) throw new IOException("Missing learning value");
            out.writeUTF(entry.getKey());
            out.writeInt(entry.getValue());
        }
    }

    private static Map<String, Integer> readStringIntMap(DataInputStream in, String name)
            throws IOException {
        int count = bounded(in.readInt(), MAX_ITEMS, name + " count");
        Map<String, Integer> values = new LinkedHashMap<>();
        for (int i = 0; i < count; i++) {
            String key = in.readUTF();
            text(key);
            int value = in.readInt();
            if (values.put(key, value) != null) throw new IOException("Duplicate " + name);
        }
        return values;
    }

    private static List<String> sorted(java.util.Collection<String> values) {
        List<String> result = new ArrayList<>(values);
        result.sort(String::compareTo);
        return result;
    }

    private static PerkFactory.Perk requirePerk(String id) throws IOException {
        PerkFactory.Perk perk = PerkFactory.Perks.FromString(id);
        if (perk == null || perk == PerkFactory.Perks.MAX || !id.equals(perk.getId())) {
            throw new IOException("Descriptor perk unavailable: " + id);
        }
        return perk;
    }

    private static byte[] writeVisual(HumanVisual visual, IsoGameCharacter timingOwner)
            throws IOException {
        if (visual == null) throw new IOException("Missing human visual");
        Outfit outfit = visual.getOutfit();
        String outfitName = outfit == null ? null : outfit.getName();
        if (outfitName != null) text(outfitName);
        Object forceModel = getField(visual, HumanVisual.class, "forceModel");
        String forceScript = (String) getField(visual, HumanVisual.class, "forceModelScript");
        if (forceModel != null && (forceScript == null || forceScript.isBlank())) {
            throw new IOException("Forced visual model has no durable script reference");
        }
        if (forceScript != null) text(forceScript);
        float beard = (Float) getField(timingOwner, IsoGameCharacter.class, "beardGrowTiming");
        float hair = (Float) getField(timingOwner, IsoGameCharacter.class, "hairGrowTiming");
        if (!Float.isFinite(beard) || !Float.isFinite(hair)) {
            throw new IOException("Invalid hair growth timing");
        }
        byte[] nativeState = serialize(buffer -> visual.save(buffer));
        ByteArrayOutputStream bytes = new ByteArrayOutputStream();
        try (DataOutputStream out = new DataOutputStream(bytes)) {
            out.writeInt(nativeState.length);
            out.write(nativeState);
            writeOptionalText(out, outfitName);
            writeOptionalText(out, forceScript);
            out.writeFloat(beard);
            out.writeFloat(hair);
        }
        return bytes.toByteArray();
    }

    private static VisualState readVisual(byte[] bytes) throws IOException {
        try (DataInputStream in = new DataInputStream(new ByteArrayInputStream(bytes))) {
            int length = bounded(in.readInt(), MAX_SECTION, "native visual size");
            if (length == 0 || length > in.available()) throw new IOException("Truncated native visual");
            byte[] nativeState = in.readNBytes(length);
            String outfit = readOptionalText(in);
            String forceScript = readOptionalText(in);
            float beard = in.readFloat(), hair = in.readFloat();
            if (!Float.isFinite(beard) || !Float.isFinite(hair)) {
                throw new IOException("Invalid hair growth timing");
            }
            if (in.available() != 0) throw new IOException("Trailing visual data");
            ByteBuffer check = ByteBuffer.wrap(nativeState);
            new HumanVisual(null).load(check, VERIFIED_WORLD_VERSION);
            consumed(check, "human visual preflight");
            return new VisualState(nativeState, outfit, forceScript, beard, hair);
        }
    }

    private static void restoreVisual(IsoPlayer shell, byte[] bytes) throws IOException {
        VisualState state = readVisual(bytes);
        Outfit outfit = null;
        if (state.outfit() != null) {
            if (OutfitManager.instance == null) throw new IOException("Outfit registry unavailable");
            outfit = shell.getDescriptor().isFemale()
                ? OutfitManager.instance.FindFemaleOutfit(state.outfit())
                : OutfitManager.instance.FindMaleOutfit(state.outfit());
            if (outfit == null) throw new IOException("Outfit unavailable: " + state.outfit());
        }
        if (state.forceModelScript() != null
                && zombie.scripting.ScriptManager.instance.getModelScript(state.forceModelScript()) == null) {
            throw new IOException("Forced model script unavailable: " + state.forceModelScript());
        }
        HumanVisual visual = shell.getHumanVisual();
        HumanVisual check = new HumanVisual(shell);
        ByteBuffer checkInput = ByteBuffer.wrap(state.nativeVisual());
        check.load(checkInput, VERIFIED_WORLD_VERSION);
        consumed(checkInput, "human visual destination preflight");
        if (!Arrays.equals(state.nativeVisual(), serialize(output -> check.save(output)))) {
            throw new IOException("Restored human visual differs");
        }
        ByteBuffer input = ByteBuffer.wrap(state.nativeVisual());
        visual.load(input, VERIFIED_WORLD_VERSION);
        consumed(input, "human visual");
        visual.setOutfit(outfit);
        visual.setForceModel(null);
        setField(visual, HumanVisual.class, "forceModelScript", null);
        if (state.forceModelScript() != null) visual.setForceModelScript(state.forceModelScript());
        setField(shell, IsoGameCharacter.class, "beardGrowTiming", state.beardGrowTiming());
        setField(shell, IsoGameCharacter.class, "hairGrowTiming", state.hairGrowTiming());
    }

    private static HumanVisual humanVisual(IsoGameCharacter character) throws IOException {
        if (character == null || !(character.getVisual() instanceof HumanVisual visual)) {
            throw new IOException("Missing human visual");
        }
        return visual;
    }

    private static void writeOptionalText(DataOutputStream out, String value) throws IOException {
        out.writeBoolean(value != null);
        if (value != null) {
            text(value);
            out.writeUTF(value);
        }
    }

    private static String readOptionalText(DataInputStream in) throws IOException {
        int present = in.readUnsignedByte();
        if (present > 1) throw new IOException("Invalid optional text");
        if (present == 0) return null;
        String value = in.readUTF();
        text(value);
        return value;
    }

    private static byte[] writeCharacterModData(IsoPlayer shell) throws IOException {
        KahluaTableImpl durable = copyDurableTable(shell.getModData(), 0,
            new IdentityHashMap<>(), true);
        return serialize(buffer -> durable.save(buffer));
    }

    private static KahluaTableImpl copyDurableTable(KahluaTable source, int depth,
            IdentityHashMap<KahluaTable, Boolean> visiting, boolean top) throws IOException {
        if (depth > MAX_DEPTH || visiting.put(source, Boolean.TRUE) != null) {
            throw new IOException("Cyclic or excessive character ModData depth");
        }
        KahluaTableImpl copy = new KahluaTableImpl(new LinkedHashMap<>());
        var iterator = source.iterator();
        while (iterator.advance()) {
            Object key = iterator.getKey(), value = iterator.getValue();
            if (top && key instanceof String name && RUNTIME_MODDATA.contains(name)) continue;
            if (!KahluaTableImpl.canSave(key, value)) {
                throw new IOException("Unsupported durable character ModData value");
            }
            checkNativeTable(key, depth + 1, new IdentityHashMap<>());
            checkNativeTable(value, depth + 1, new IdentityHashMap<>());
            Object copied = value instanceof KahluaTable nested
                ? copyDurableTable(nested, depth + 1, visiting, false) : value;
            copy.rawset(key, copied);
        }
        visiting.remove(source);
        return copy;
    }

    private static KahluaTableImpl readCharacterModData(byte[] bytes) throws IOException {
        KahluaTableImpl table = new KahluaTableImpl(new LinkedHashMap<>());
        ByteBuffer input = ByteBuffer.wrap(bytes);
        table.load(input, VERIFIED_WORLD_VERSION);
        consumed(input, "character ModData");
        checkNativeTable(table, 0, new IdentityHashMap<>());
        return table;
    }

    private static void restoreCharacterModData(IsoPlayer shell, byte[] bytes) throws IOException {
        KahluaTableImpl durable = readCharacterModData(bytes);
        KahluaTable destination = shell.getModData();
        Map<String, Object> runtime = new LinkedHashMap<>();
        for (String key : RUNTIME_MODDATA) {
            Object value = destination.rawget(key);
            if (value != null) runtime.put(key, value);
        }
        destination.wipe();
        var iterator = durable.iterator();
        while (iterator.advance()) destination.rawset(iterator.getKey(), iterator.getValue());
        for (Map.Entry<String, Object> entry : runtime.entrySet()) {
            destination.rawset(entry.getKey(), entry.getValue());
        }
    }

    private static Object getField(Object owner, Class<?> type, String name) throws IOException {
        try {
            Field field = type.getDeclaredField(name);
            field.setAccessible(true);
            return field.get(owner);
        } catch (ReflectiveOperationException | RuntimeException error) {
            throw new IOException("Engine field unavailable: " + type.getSimpleName() + "." + name, error);
        }
    }

    private static void setField(Object owner, Class<?> type, String name, Object value)
            throws IOException {
        try {
            Field field = type.getDeclaredField(name);
            field.setAccessible(true);
            field.set(owner, value);
        } catch (ReflectiveOperationException | RuntimeException error) {
            throw new IOException("Engine field unavailable: " + type.getSimpleName() + "." + name, error);
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

    private static Map<Integer, byte[]> fluidFacts(Map<Integer, InventoryItem> items)
            throws IOException {
        Map<Integer, byte[]> facts = new LinkedHashMap<>();
        for (Map.Entry<Integer, InventoryItem> entry : items.entrySet()) {
            var fluid = entry.getValue().getFluidContainer();
            if (fluid != null) facts.put(entry.getKey(), serialize(buffer -> fluid.save(buffer)));
        }
        return facts;
    }

    private static void checkFluidFacts(Map<Integer, InventoryItem> items,
            Map<Integer, byte[]> expected) throws IOException {
        Map<Integer, byte[]> actual = fluidFacts(items);
        if (!actual.keySet().equals(expected.keySet())) {
            throw new IOException("Restored fluid-container ownership differs");
        }
        for (Integer id : expected.keySet()) {
            if (!Arrays.equals(expected.get(id), actual.get(id))) {
                throw new IOException("Restored fluid mixture differs");
            }
        }
    }

    private static byte[] writeManifest(Map<Integer, ItemFact> items, Equipment equipment,
            Map<Integer, byte[]> fluids) throws IOException {
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
            out.writeInt(fluids.size());
            for (Map.Entry<Integer, byte[]> entry : fluids.entrySet()) {
                checkReference(items, entry.getKey());
                if (entry.getValue().length == 0 || entry.getValue().length > MAX_SECTION) {
                    throw new IOException("Invalid fluid component size");
                }
                out.writeInt(entry.getKey());
                out.writeInt(entry.getValue().length);
                out.write(entry.getValue());
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

    private static Manifest readManifest(byte[] bytes, int schema) throws IOException {
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
            Map<Integer, byte[]> fluids = new LinkedHashMap<>();
            if (schema >= 4) {
                int fluidCount = bounded(in.readInt(), MAX_ITEMS, "fluid component count");
                for (int i = 0; i < fluidCount; i++) {
                    int id = in.readInt();
                    checkReference(items, id);
                    int size = bounded(in.readInt(), MAX_SECTION, "fluid component size");
                    if (size == 0 || size > in.available() || fluids.put(id, in.readNBytes(size)) != null) {
                        throw new IOException("Invalid fluid component fact");
                    }
                }
            }
            if (in.available() != 0) throw new IOException("Trailing manifest data");
            return new Manifest(items, new Equipment(primary, secondary, worn, attached), fluids);
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
        int schema;
        String prefix;
        int magic;
        int sectionCount;
        if (packed != null && packed.startsWith(PREFIX_V4)) {
            schema = 4; prefix = PREFIX_V4; magic = MAGIC_V4; sectionCount = SECTIONS_V4;
        } else if (packed != null && packed.startsWith(PREFIX_V3)) {
            schema = 3; prefix = PREFIX_V3; magic = MAGIC_V3; sectionCount = SECTIONS_V3;
        } else {
            throw new IOException("Invalid snapshot encoding or size");
        }
        if (packed.length() > prefix.length() + 4L * ((MAX_BINARY + 2) / 3)) {
            throw new IOException("Invalid snapshot encoding or size");
        }
        byte[] bytes;
        try {
            bytes = Base64.getDecoder().decode(packed.substring(prefix.length()));
        } catch (IllegalArgumentException error) {
            throw new IOException("Invalid snapshot Base64", error);
        }
        if (bytes.length < 16 + sectionCount * 4 + DIGEST_BYTES || bytes.length > MAX_BINARY) {
            throw new IOException("Invalid snapshot length");
        }
        int payloadSize = bytes.length - DIGEST_BYTES;
        if (!MessageDigest.isEqual(hash(Arrays.copyOf(bytes, payloadSize)),
                Arrays.copyOfRange(bytes, payloadSize, bytes.length))) {
            throw new IOException("Snapshot checksum mismatch");
        }
        try (DataInputStream in = new DataInputStream(
                new ByteArrayInputStream(bytes, 0, payloadSize))) {
            if (in.readInt() != magic || in.readInt() != FORMAT) {
                throw new IOException("Unsupported snapshot format");
            }
            int version = in.readInt();
            if (version != VERIFIED_WORLD_VERSION || IsoWorld.getWorldVersion() != version) {
                throw new IOException("Unsupported engine snapshot version");
            }
            if (in.readInt() != sectionCount) throw new IOException("Invalid component count");
            byte[][] sections = new byte[sectionCount][];
            for (int i = 0; i < sectionCount; i++) {
                int size = bounded(in.readInt(), MAX_SECTION, "component size");
                if (size == 0 || size > in.available()) throw new IOException("Truncated component");
                sections[i] = in.readNBytes(size);
            }
            if (in.available() != 0) throw new IOException("Trailing snapshot data");
            if (sections[1].length != zombie.characters.CharacterStat.ORDERED_STATS.length * 4) {
                throw new IOException("Unexpected native stat layout");
            }
            checkExperience(sections[3]);
            if (schema >= 4) {
                checkNutrition(sections[5]);
                checkFitness(sections[6]);
                readLearning(sections[7]);
                readVisual(sections[8]);
                readCharacterModData(sections[9]);
            }
            return new Snapshot(schema, version, sections, readManifest(sections[4], schema));
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
