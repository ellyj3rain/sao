import com.sao.engine.SAONativeSnapshot;
import zombie.characters.IsoPlayer;
import zombie.characters.IsoZombie;
import zombie.characters.SurvivorDesc;
import zombie.core.skinnedmodel.visual.ItemVisual;
import zombie.core.skinnedmodel.population.ClothingItem;
import zombie.asset.Asset;
import zombie.asset.AssetPath;
import zombie.inventory.InventoryItem;
import zombie.inventory.InventoryItemFactory;
import zombie.scripting.ScriptManager;
import zombie.scripting.objects.Item;
import zombie.scripting.objects.ItemBodyLocation;
import zombie.scripting.objects.ItemType;
import zombie.scripting.objects.ScriptModule;
import zombie.world.WorldDictionary;
import java.lang.reflect.Field;
import java.lang.reflect.Method;

/** Installed-engine Week One visual clothing conversion and ownership probe. */
public final class WeekOneSnapshotProbe {
    private static void check(boolean value, String message) {
        if (!value) throw new AssertionError(message);
    }

    private static IsoPlayer person() {
        SurvivorDesc desc = new SurvivorDesc();
        desc.getHumanVisual().setSkinTextureName("fixture");
        return new IsoPlayer(null, desc, 0, 0, 0, false);
    }

    public static void main(String[] args) throws Exception {
        PersonSnapshotProbe.main(args);
        ScriptModule module = ScriptManager.instance.moduleMap.get("C51");
        Item shirt = new Item();
        shirt.setModule(module);
        shirt.setName("WeekOneShirt");
        shirt.setRegistry_id((short) 5);
        shirt.displayName = "Week One Shirt";
        shirt.setItemType(ItemType.CLOTHING);
        shirt.setBodyLocation(ItemBodyLocation.SHIRT);
        shirt.canBeEquipped = ItemBodyLocation.SHIRT;
        shirt.clothingItem = "WeekOneShirt";
        ClothingItem asset = new ClothingItem(new AssetPath("WeekOneShirt"), null);
        asset.mame = "WeekOneShirt";
        asset.baseTextures.add("weekone_fixture");
        asset.onCreated(Asset.State.READY);
        shirt.setClothingItemAsset(asset);
        module.items.getScriptMap().put("WeekOneShirt", shirt);
        Field itemsField = ScriptManager.class.getDeclaredField("items");
        itemsField.setAccessible(true);
        zombie.scripting.ScriptBucketCollection<?> items =
            (zombie.scripting.ScriptBucketCollection<?>) itemsField.get(ScriptManager.instance);
        items.registerModule(module);
        Field dictionaryField = WorldDictionary.class.getDeclaredField("data");
        dictionaryField.setAccessible(true);
        Object dictionary = dictionaryField.get(null);
        Method register = dictionary.getClass().getDeclaredMethod("register", Item.class, short.class);
        register.setAccessible(true);
        register.invoke(dictionary, shirt, (short) 5);
        zombie.characters.WornItems.BodyLocations.getGroup("Human")
            .getOrCreateLocation(ItemBodyLocation.SHIRT);
        InventoryItem physical = InventoryItemFactory.CreateItem("C51.WeekOneShirt");
        System.out.println("fixture item=" + physical + " class="
            + (physical == null ? "null" : physical.getClass().getName())
            + " location=" + (physical == null ? "null" : physical.canBeEquipped())
            + " visual=" + (physical == null ? "null" : physical.getVisual())
            + " scriptLocation=" + shirt.getBodyLocation());
        check(physical != null && physical.getScriptItem().getBodyLocation() == ItemBodyLocation.SHIRT,
            "fixture clothing cannot be equipped");
        check(physical.getVisual() != null, "fixture clothing has no native item visual");
        SurvivorDesc desc = new SurvivorDesc();
        desc.getHumanVisual().setSkinTextureName("weekone-person");
        IsoZombie source = new IsoZombie(null, desc, 0);
        ItemVisual visual = new ItemVisual();
        visual.setItemType("C51.WeekOneShirt");
        source.getItemVisuals().add(visual);
        check(!source.isUsingWornItems(), "Week One source unexpectedly owns worn items");
        String packed = SAONativeSnapshot.captureWeekOne(source, person());
        check(SAONativeSnapshot.validate(packed), "Week One snapshot invalid");
        IsoPlayer restored = person();
        check(SAONativeSnapshot.restoreStaged(restored, packed) == 1,
            "Week One visual clothing did not become one physical item");
        InventoryItem worn = restored.getWornItem(ItemBodyLocation.SHIRT);
        check(worn != null && "C51.WeekOneShirt".equals(worn.getFullType()),
            "Week One clothing did not retain type/location");
        check(restored.getInventory().getItems().size() == 1
            && source.getInventory().getItems().isEmpty()
            && source.getWornItems().size() == 0,
            "Week One clothing acquired duplicate ownership");
        source.getItemVisuals().add(visual);
        boolean duplicateRefused = false;
        try { SAONativeSnapshot.captureWeekOne(source, person()); }
        catch (Exception expected) { duplicateRefused = true; }
        check(duplicateRefused, "duplicate clothing location was accepted");
        System.out.println("PASS Week One native visual-to-physical snapshot and duplicate refusal");
    }
}
