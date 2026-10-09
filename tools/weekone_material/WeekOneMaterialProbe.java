import com.sao.engine.SAONativeSnapshot;
import java.lang.reflect.Field;
import java.util.LinkedHashMap;
import java.util.Map;
import se.krka.kahlua.j2se.KahluaTableImpl;
import zombie.characters.IsoPlayer;
import zombie.characters.IsoZombie;
import zombie.characters.SurvivorDesc;
import zombie.inventory.InventoryItem;
import zombie.inventory.InventoryItemFactory;
import zombie.inventory.types.HandWeapon;
import zombie.inventory.types.InventoryContainer;
import zombie.scripting.ScriptManager;
import zombie.scripting.objects.Item;
import zombie.scripting.objects.ItemType;
import zombie.scripting.objects.ScriptModule;
import zombie.world.DictionaryData;
import zombie.world.ItemInfo;
import zombie.world.WorldDictionary;

/** Headless installed-engine transfer of an armed Week One brain and body. */
public final class WeekOneMaterialProbe {
    private static short nextRegistry = 40;

    private static final class Info extends ItemInfo {
        Info(Item item, short id, String module) {
            name = item.getName();
            moduleName = module;
            fullType = module + "." + name;
            registryId = id;
            isLoaded = true;
            scriptItem = item;
            entityScript = item;
            modId = "fixture";
        }
    }

    private static KahluaTableImpl table(Object... entries) {
        KahluaTableImpl result = new KahluaTableImpl(new LinkedHashMap<>());
        for (int i = 0; i < entries.length; i += 2) result.rawset(entries[i], entries[i + 1]);
        return result;
    }

    private static void check(boolean value, String message) {
        if (!value) throw new AssertionError(message);
    }

    @SuppressWarnings("unchecked")
    private static void register(String moduleName, String name, ItemType kind,
            int capacity, String magazineType) throws Exception {
        ScriptModule module = ScriptManager.instance.moduleMap.computeIfAbsent(moduleName, key -> {
            ScriptModule created = new ScriptModule();
            created.name = key;
            return created;
        });
        Item item = new Item();
        item.setModule(module);
        item.setName(name);
        short registry = nextRegistry++;
        item.setRegistry_id(registry);
        item.displayName = name;
        item.setItemType(kind);
        item.maxAmmo = capacity;
        if (magazineType != null) {
            Field magazine = Item.class.getDeclaredField("magazineType");
            magazine.setAccessible(true);
            magazine.set(item, magazineType);
        }
        module.items.getScriptMap().put(name, item);
        Field dictionary = WorldDictionary.class.getDeclaredField("data");
        dictionary.setAccessible(true);
        DictionaryData data = (DictionaryData) dictionary.get(null);
        for (String fieldName : new String[] {"itemIdToInfoMap", "itemTypeToInfoMap"}) {
            Field field = DictionaryData.class.getDeclaredField(fieldName);
            field.setAccessible(true);
            Map<Object, ItemInfo> map = (Map<Object, ItemInfo>) field.get(data);
            map.put(fieldName.equals("itemIdToInfoMap") ? registry : moduleName + "." + name,
                new Info(item, registry, moduleName));
        }
        Field items = ScriptManager.class.getDeclaredField("items");
        items.setAccessible(true);
        zombie.scripting.ScriptBucketCollection<?> bucket =
            (zombie.scripting.ScriptBucketCollection<?>) items.get(ScriptManager.instance);
        bucket.registerModule(module);
    }

    private static IsoPlayer person() {
        SurvivorDesc desc = new SurvivorDesc();
        desc.getHumanVisual().setSkinTextureName("weekone-material-fixture");
        return new IsoPlayer(null, desc, 0, 0, 0, false);
    }

    private static KahluaTableImpl brain(IsoZombie source) {
        return table("id", (double) source.getPersistentOutfitID(), "born", 12.5,
            "saoWeekOneOrigin", "BanditsWeekOne", "health", 1.5,
            "infection", 0.0,
            "inventory", table(), "loot", table(),
            "weapons", table("melee", "C51.Hammer",
                "primary", table("name", "C51.Rifle", "type", "mag",
                    "clipIn", true, "racked", false, "magName", "C51.Mag",
                    "magSize", 15.0, "bulletsLeft", 7.0, "magCount", 2.0),
                "secondary", table("bulletsLeft", 0.0, "magCount", 0.0)),
            "keys", table("hospital", 612.0),
            "permaInv", table(1.0, table("fullType", "C51.Food",
                "calories", 440.0, "hungerChange", -0.25)),
            "bag", table("name", "C51.Bag"));
    }

    private static int count(zombie.inventory.ItemContainer inventory, String type) {
        int total = 0;
        for (InventoryItem item : inventory.getItems()) {
            if (type.equals(item.getFullType())) total++;
        }
        return total;
    }

    private static void refuses(IsoZombie source, KahluaTableImpl brain, String reason)
            throws Exception {
        try {
            SAONativeSnapshot.captureWeekOne(source, person(), brain);
            throw new AssertionError("Accepted " + reason);
        } catch (java.io.IOException expected) { }
    }

    public static void main(String[] args) throws Exception {
        PersonSnapshotProbe.main(args);
        register("C51", "Hammer", ItemType.WEAPON, 0, null);
        register("C51", "Rifle", ItemType.WEAPON, 15, "C51.Mag");
        register("C51", "Mag", ItemType.NORMAL, 15, null);
        register("C51", "Food", ItemType.FOOD, 0, null);
        register("C51", "Bag", ItemType.CONTAINER, 0, null);
        register("Base", "Key1", ItemType.KEY, 0, null);
        SurvivorDesc desc = new SurvivorDesc();
        desc.getHumanVisual().setSkinTextureName("weekone-source-fixture");
        IsoZombie source = new IsoZombie(null, desc, 0);
        source.setHealth(.75f);
        source.setPrimaryHandItem(InventoryItemFactory.CreateItem("C51.Rifle"));
        source.getInventory().AddItem("C51.Food");
        KahluaTableImpl brain = brain(source);
        String packed = SAONativeSnapshot.captureWeekOne(source, person(), brain);
        check(SAONativeSnapshot.validate(packed), "armed material snapshot failed validation");
        IsoPlayer restored = person();
        SAONativeSnapshot.restoreStaged(restored, packed);
        check(count(restored.getInventory(), "C51.Rifle") == 1
                && count(restored.getInventory(), "C51.Mag") == 2
                && count(restored.getInventory(), "C51.Hammer") == 1
                && count(restored.getInventory(), "C51.Food") == 2
                && count(restored.getInventory(), "C51.Bag") == 1
                && count(restored.getInventory(), "Base.Key1") == 1,
            "armed Week One belongings were lost or duplicated");
        HandWeapon gun = (HandWeapon) restored.getPrimaryHandItem();
        check(gun != null && "C51.Rifle".equals(gun.getFullType())
                && gun.getCurrentAmmoCount() == 7 && gun.isContainsClip(),
            "virtual firearm rounds did not become one equipped native gun");
        check(Math.abs(restored.getBodyDamage().getOverallBodyHealth() - 50f) < .01f
                && Math.abs((Double) restored.getModData().rawget("SAOWeekOneSourceHealth")
                    - .75) < .01,
            "injured source health was not retained in the native snapshot");
        boolean key = false, food = false, bag = false;
        for (InventoryItem item : restored.getInventory().getItems()) {
            if (item.getFullType().equals("Base.Key1")) key = item.getKeyId() == 612;
            if (item.getFullType().equals("C51.Food")
                    && "permanent".equals(item.getModData().rawget("SAOWeekOneMaterialKind"))) {
                food = item instanceof zombie.inventory.types.Food sourceFood
                    && sourceFood.getCalories() == 440.0f;
            }
            if (item.getFullType().equals("C51.Bag")) bag = item instanceof InventoryContainer;
        }
        check(key && food && bag, "key, food or bag detail failed native restore");
        check(source.getInventory().getItems().size() == 1
                && source.getPrimaryHandItem() != null,
            "detached transfer changed the Bandits source body");
        InventoryItem physicalKey = source.getInventory().AddItem("Base.Key1");
        physicalKey.setKeyId(612);
        source.getInventory().AddItem("C51.Bag");
        String withPhysical = SAONativeSnapshot.captureWeekOne(source, person(), brain);
        IsoPlayer restoredPhysical = person();
        SAONativeSnapshot.restoreStaged(restoredPhysical, withPhysical);
        check(count(restoredPhysical.getInventory(), "Base.Key1") == 1
                && count(restoredPhysical.getInventory(), "C51.Bag") == 1
                && source.getInventory().getItems().size() == 3,
            "a physically carried key or bag was duplicated by its brain entry");
        KahluaTableImpl foreign = brain(source);
        foreign.rawset("saoWeekOneOrigin", "Bandits2");
        refuses(source, foreign, "foreign source");
        KahluaTableImpl mismatched = brain(source);
        mismatched.rawset("id", (double) source.getPersistentOutfitID() + 1);
        refuses(source, mismatched, "mismatched brain id");
        KahluaTableImpl wrongAmmo = brain(source);
        ((KahluaTableImpl) ((KahluaTableImpl) wrongAmmo.rawget("weapons")).rawget("primary"))
            .rawset("magSize", 17.0);
        refuses(source, wrongAmmo, "mismatched magazine capacity");
        KahluaTableImpl virtualLoot = brain(source);
        virtualLoot.rawset("loot", table(1.0, "Base.Mystery"));
        refuses(source, virtualLoot, "unresolved virtual loot");
        KahluaTableImpl infected = brain(source);
        infected.rawset("infection", 8.0);
        refuses(source, infected, "unsupported infection progression");
        String truncated = packed.substring(0, packed.length() - 1);
        check(!SAONativeSnapshot.validate(truncated), "corrupt reload was admitted");
        System.out.println("PASS Week One armed native inventory and guarded reload inverses");
    }
}
