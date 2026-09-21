import com.sao.engine.SAONativeSnapshot;
import com.sao.engine.SAOPrivateInventory;
import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.DataInputStream;
import java.io.DataOutputStream;
import java.nio.ByteBuffer;
import java.security.MessageDigest;
import java.util.Arrays;
import java.util.Base64;
import java.util.HashMap;
import java.util.Map;
import zombie.characters.IsoPlayer;
import zombie.characters.SurvivorDesc;
import zombie.inventory.InventoryItem;
import zombie.inventory.types.Food;
import zombie.inventory.types.HandWeapon;
import zombie.inventory.types.InventoryContainer;
import zombie.scripting.ScriptManager;
import zombie.scripting.objects.Item;
import zombie.scripting.objects.ItemType;
import zombie.scripting.objects.ScriptModule;
import zombie.world.DictionaryData;
import zombie.world.ItemInfo;
import zombie.world.WorldDictionary;

/** Installed-engine proof for C71's exact recursive private inventory. */
public final class PrivateInventoryProbe {
    private static int nextId = 7100;
    private static final FixtureDictionary DICTIONARY = new FixtureDictionary();

    private static final class FixtureInfo extends ItemInfo {
        FixtureInfo(Item definition, short id) {
            name = definition.getName();
            moduleName = "C71";
            fullType = "C71." + name;
            registryId = id;
            isLoaded = true;
            scriptItem = definition;
            entityScript = definition;
            modId = "fixture";
        }
    }

    private static final class FixtureDictionary extends DictionaryData {
        void register(Item definition, short id) {
            FixtureInfo info = new FixtureInfo(definition, id);
            itemIdToInfoMap.put(id, info);
            itemTypeToInfoMap.put(info.getFullType(), info);
        }
    }

    private static final class FixtureItem {
        private final Item definition = new Item();
        FixtureItem(ScriptModule module, String name, ItemType kind, short id) {
            definition.setModule(module);
            definition.setName(name);
            definition.setRegistry_id(id);
            definition.displayName = name;
            definition.setItemType(kind);
            module.items.getScriptMap().put(name, definition);
            DICTIONARY.register(definition, id);
        }
        InventoryItem create() {
            InventoryItem item = definition.InstanceItem(null, false);
            item.id = nextId++;
            return item;
        }
    }

    private static IsoPlayer person(String id) {
        SurvivorDesc desc = new SurvivorDesc();
        desc.setFemale(false);
        desc.getHumanVisual().setSkinTextureName("fixture");
        IsoPlayer person = new IsoPlayer(null, desc, 0, 0, 0, false);
        person.getModData().rawset("SAOPersonId", id);
        return person;
    }

    private static void check(boolean condition, String marker) {
        if (!condition) throw new AssertionError(marker);
    }

    private static Map<Integer, Integer> parents(SAOPrivateInventory.View view) {
        Map<Integer, Integer> rows = new HashMap<>();
        for (SAOPrivateInventory.Holder holder : view.holders()) {
            for (SAOPrivateInventory.ItemRef item : holder.items()) {
                check(rows.put(item.itemId(), item.parentItemId()) == null,
                    "holder_conservation");
            }
        }
        return rows;
    }

    private static String downgradeV3(String packed) throws Exception {
        byte[] encoded = Base64.getDecoder().decode(packed.substring(3));
        int payloadLength = encoded.length - 32;
        byte[][] sections = new byte[5][];
        try (DataInputStream in = new DataInputStream(
                new ByteArrayInputStream(encoded, 0, payloadLength))) {
            in.readInt(); in.readInt(); in.readInt();
            check(in.readInt() == 10, "v4_sections");
            for (int i = 0; i < 5; i++) {
                sections[i] = in.readNBytes(in.readInt());
            }
        }
        check(ByteBuffer.wrap(sections[4], sections[4].length - 4, 4)
            .getInt() == 0, "v3_fixture_fluid");
        sections[4] = Arrays.copyOf(sections[4], sections[4].length - 4);
        ByteArrayOutputStream payload = new ByteArrayOutputStream();
        try (DataOutputStream out = new DataOutputStream(payload)) {
            out.writeInt(0x53414f33);
            out.writeInt(1);
            out.writeInt(249);
            out.writeInt(5);
            for (byte[] section : sections) {
                out.writeInt(section.length);
                out.write(section);
            }
        }
        payload.write(MessageDigest.getInstance("SHA-256")
            .digest(payload.toByteArray()));
        return "v3;" + Base64.getEncoder().encodeToString(payload.toByteArray());
    }

    private static void boot() throws Exception {
        zombie.core.random.RandStandard.INSTANCE.init();
        zombie.ZomboidFileSystem.instance.init();
        zombie.SoundManager.instance = new zombie.DummySoundManager();
        zombie.Lua.LuaManager.platform = new se.krka.kahlua.j2se.J2SEPlatform();
        zombie.Lua.LuaManager.env = zombie.Lua.LuaManager.platform.newTable();
        zombie.Lua.LuaEventManager.register(zombie.Lua.LuaManager.platform,
            zombie.Lua.LuaManager.env);
        SurvivorDesc.HairCommonColors.add(
            new zombie.core.ImmutableColor(.2f, .3f, .4f));
        zombie.core.skinnedmodel.population.HairStyles.instance =
            new zombie.core.skinnedmodel.population.HairStyles();
        zombie.core.skinnedmodel.population.BeardStyles.instance =
            new zombie.core.skinnedmodel.population.BeardStyles();
        var hair = new zombie.core.skinnedmodel.population.HairStyle();
        hair.name = "C71Hair";
        hair.model = "C71HairModel";
        hair.texture = "C71HairTexture";
        zombie.core.skinnedmodel.population.HairStyles.instance.maleStyles.add(hair);
        zombie.core.skinnedmodel.population.HairStyles.instance.femaleStyles.add(hair);
        var beard = new zombie.core.skinnedmodel.population.BeardStyle();
        beard.name = "C71Beard";
        beard.model = "C71BeardModel";
        beard.texture = "C71BeardTexture";
        zombie.core.skinnedmodel.population.BeardStyles.instance.styles.add(beard);
        zombie.core.skinnedmodel.population.OutfitManager.instance =
            new zombie.core.skinnedmodel.population.OutfitManager();
        zombie.GameTime.setInstance(new zombie.GameTime());
        zombie.GameTime.getInstance().updateCalendar(1993, 0, 1, 12, 0);
        zombie.characters.skills.PerkFactory.init();
        var field = WorldDictionary.class.getDeclaredField("data");
        field.setAccessible(true);
        field.set(null, DICTIONARY);
    }

    public static void main(String[] args) throws Exception {
        boot();
        ScriptModule module = new ScriptModule();
        module.name = "C71";
        ScriptManager.instance.moduleMap.put("C71", module);
        FixtureItem bagDefinition = new FixtureItem(module, "Bag",
            ItemType.CONTAINER, (short) 71);
        FixtureItem foodDefinition = new FixtureItem(module, "Food",
            ItemType.FOOD, (short) 72);
        FixtureItem weaponDefinition = new FixtureItem(module, "Weapon",
            ItemType.WEAPON, (short) 73);

        IsoPlayer source = person("person-71");
        InventoryContainer bag = (InventoryContainer) bagDefinition.create();
        Food nested = (Food) foodDefinition.create();
        HandWeapon root = (HandWeapon) weaponDefinition.create();
        bag.getInventory().AddItem(nested);
        source.getInventory().AddItem(bag);
        source.getInventory().AddItem(root);

        var recursive = SAOPrivateInventory.carriedItems(source);
        check(recursive.size() == 3 && recursive.contains(nested),
            "nested_loaded");
        check(SAOPrivateInventory.rootContainer(nested.getContainer())
            == source.getInventory(), "root_holder");
        SAOPrivateInventory.View loaded = SAOPrivateInventory.carriedView(source);
        Map<Integer, Integer> loadedParents = parents(loaded);
        check(loadedParents.size() == 3
                && loadedParents.get(nested.id).equals(bag.id),
            "loaded_parent");

        String packed = SAONativeSnapshot.capture(source);
        SAOPrivateInventory.View dormant =
            SAOPrivateInventory.dormantView("person-71", packed);
        check(parents(dormant).equals(loadedParents)
                && dormant.revision().equals(loaded.revision()),
            "loaded_dormant_agreement");
        check(SAOPrivateInventory.carriedView(source).revision()
                .equals(loaded.revision())
                && source.getInventory().contains(bag)
                && bag.getInventory().contains(nested),
            "read_mutated_inventory");

        bag.getInventory().Remove(nested);
        SAOPrivateInventory.View removed = SAOPrivateInventory.carriedView(source);
        check(!parents(removed).containsKey(nested.id)
                && !removed.revision().equals(loaded.revision()),
            "removal_refresh");
        Food replacement = (Food) foodDefinition.create();
        bag.getInventory().AddItem(replacement);
        SAOPrivateInventory.View replaced = SAOPrivateInventory.carriedView(source);
        check(parents(replaced).containsKey(replacement.id)
                && !parents(replaced).containsKey(nested.id),
            "replacement_identity");

        bag.getInventory().Remove(replacement);
        source.getInventory().AddItem(replacement);
        SAOPrivateInventory.View transferred = SAOPrivateInventory.carriedView(source);
        Map<Integer, Integer> transferredParents = parents(transferred);
        check(transferredParents.containsKey(replacement.id)
                && transferredParents.get(replacement.id) == null
                && transferredParents.size() == 3,
            "holder_transfer");

        String finalPacked = SAONativeSnapshot.capture(source);
        IsoPlayer restored = person("person-71");
        SAONativeSnapshot.restoreStaged(restored, finalPacked);
        check(SAOPrivateInventory.carriedView(restored).revision().equals(
                SAOPrivateInventory.dormantView("person-71", finalPacked)
                    .revision()),
            "reload_agreement");

        SAOPrivateInventory.View old = SAOPrivateInventory.dormantView(
            "person-71", downgradeV3(finalPacked));
        check("unknown".equals(old.carriedCoverage()) && old.holders().isEmpty(),
            "v3_refusal");
        check(SAOPrivateInventory.dormantView("person-71", "v2;legacy")
                .holders().isEmpty(), "legacy_refusal");
        String encoded = SAOPrivateInventory.encodeDormant("person-71",
            finalPacked);
        check(encoded.contains("aggregate=refused")
                && encoded.contains("world=unknown"),
            "aggregate_or_world_inferred");

        System.out.println("PASS private inventory: recursive exact holders; "
            + "loaded/dormant/reload agreement; remove/replace/transfer; "
            + "legacy refusal; aggregate refusal");
    }
}
