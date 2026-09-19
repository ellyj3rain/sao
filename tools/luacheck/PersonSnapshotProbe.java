import com.sao.engine.SAONativeSnapshot;
import java.lang.reflect.Field;
import java.nio.ByteBuffer;
import java.security.MessageDigest;
import java.util.Arrays;
import java.util.Base64;
import zombie.characters.CharacterStat;
import zombie.characters.IsoPlayer;
import zombie.characters.SurvivorDesc;
import zombie.characters.BodyDamage.BodyPartType;
import zombie.characters.skills.PerkFactory;
import zombie.inventory.InventoryItem;
import zombie.inventory.types.Food;
import zombie.inventory.types.HandWeapon;
import zombie.inventory.types.InventoryContainer;
import zombie.inventory.types.Key;
import zombie.scripting.ScriptManager;
import zombie.scripting.objects.CharacterTrait;
import zombie.scripting.objects.Item;
import zombie.scripting.objects.ItemBodyLocation;
import zombie.scripting.objects.ItemType;
import zombie.scripting.objects.ScriptModule;
import zombie.world.DictionaryData;
import zombie.world.ItemInfo;
import zombie.world.WorldDictionary;

/**
 * Actual installed-engine component roundtrip, without a world or save files.
 * Fixture registry entries create real native item classes; their serializers,
 * nested-container loaders, Stats, BodyDamage and XP execute unchanged.
 * Appearance pools/audio/events are minimal explicit headless boot fixtures.
 * No reflection changes any production serializer or snapshot implementation.
 */
public final class PersonSnapshotProbe {
    private static int nextId = 1000;
    private static final FixtureDictionary DICTIONARY = new FixtureDictionary();

    private static final class FixtureInfo extends ItemInfo {
        FixtureInfo(Item definition, short id) {
            name = definition.getName();
            moduleName = "C51";
            fullType = "C51." + name;
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
        void missing(short id) { itemIdToInfoMap.remove(id); }
    }

    private static final class FixtureItem {
        private final Item definition = new Item();
        FixtureItem(ScriptModule module, String name, String kind, short id) {
            definition.setModule(module);
            definition.setName(name);
            definition.setRegistry_id(id);
            definition.displayName = name;
            definition.setItemType(switch (kind) {
                case "bag" -> ItemType.CONTAINER;
                case "key" -> ItemType.KEY;
                case "food" -> ItemType.FOOD;
                default -> ItemType.WEAPON;
            });
            module.items.getScriptMap().put(name, definition);
            DICTIONARY.register(definition, id);
        }
        public InventoryItem InstanceItem(String unused, boolean callbacks) {
            InventoryItem item = definition.InstanceItem(unused, callbacks);
            item.id = nextId++;
            return item;
        }
    }

    private static IsoPlayer person() {
        SurvivorDesc desc = new SurvivorDesc();
        desc.getHumanVisual().setSkinTextureName("fixture");
        return new IsoPlayer(null, desc, 0, 0, 0, false);
    }

    private static void check(boolean condition, String message) {
        if (!condition) throw new AssertionError(message);
    }

    private static String alteredVersion(String packed) throws Exception {
        byte[] bytes = Base64.getDecoder().decode(packed.substring(3));
        ByteBuffer.wrap(bytes).putInt(8, 248);
        byte[] digest = MessageDigest.getInstance("SHA-256")
                .digest(Arrays.copyOf(bytes, bytes.length - 32));
        System.arraycopy(digest, 0, bytes, bytes.length - 32, 32);
        return "v3;" + Base64.getEncoder().encodeToString(bytes);
    }

    @SuppressWarnings("unchecked")
    private static void missingPerkRefused(String packed, PerkFactory.Perk perk) throws Exception {
        Field field = PerkFactory.class.getDeclaredField("PerkById");
        field.setAccessible(true);
        var registry = (java.util.Map<String, PerkFactory.Perk>) field.get(null);
        registry.remove(perk.getId());
        try {
            check(!SAONativeSnapshot.validate(packed), "missing custom perk accepted by preflight");
            boolean refused = false;
            try { SAONativeSnapshot.restore(person(), packed); }
            catch (Exception expected) { refused = true; }
            check(refused, "missing custom perk accepted by restore");
        } finally {
            registry.put(perk.getId(), perk);
        }
    }

    @SuppressWarnings("unchecked")
    private static void missingTraitRefused(String packed, CharacterTrait trait) throws Exception {
        var registry = zombie.scripting.objects.Registries.CHARACTER_TRAIT;
        var location = registry.getLocation(trait);
        Field field = registry.getClass().getDeclaredField("byLocation");
        field.setAccessible(true);
        var values = (java.util.Map<zombie.scripting.objects.ResourceLocation, CharacterTrait>) field.get(registry);
        values.remove(location);
        try {
            check(!SAONativeSnapshot.validate(packed), "missing custom trait accepted by preflight");
            boolean refused = false;
            try { SAONativeSnapshot.restore(person(), packed); }
            catch (Exception expected) { refused = true; }
            check(refused, "missing custom trait accepted by restore");
        } finally {
            values.put(location, trait);
        }
    }

    public static void main(String[] args) throws Exception {
        zombie.core.random.RandStandard.INSTANCE.init();
        zombie.ZomboidFileSystem.instance.init();
        zombie.SoundManager.instance = new zombie.DummySoundManager();
        zombie.Lua.LuaManager.platform = new se.krka.kahlua.j2se.J2SEPlatform();
        zombie.Lua.LuaManager.env = zombie.Lua.LuaManager.platform.newTable();
        zombie.Lua.LuaEventManager.register(zombie.Lua.LuaManager.platform,
                zombie.Lua.LuaManager.env);
        SurvivorDesc.HairCommonColors.add(new zombie.core.ImmutableColor(.2f, .3f, .4f));
        zombie.core.skinnedmodel.population.HairStyles.instance =
                new zombie.core.skinnedmodel.population.HairStyles();
        zombie.core.skinnedmodel.population.BeardStyles.instance =
                new zombie.core.skinnedmodel.population.BeardStyles();
        zombie.characters.WornItems.BodyLocations.getGroup("Human")
                .getOrCreateLocation(ItemBodyLocation.BACK);
        zombie.characters.AttachedItems.AttachedLocations.getGroup("Human")
                .getOrCreateLocation("FixtureSlot");
        PerkFactory.init();
        var earnedPerk = new PerkFactory.Perk("C51Earned");
        var levelPerk = new PerkFactory.Perk("C51Level");
        var multiplierPerk = new PerkFactory.Perk("C51Multiplier");
        CharacterTrait customTrait = CharacterTrait.register("C51:FixtureTrait");
        Field data = WorldDictionary.class.getDeclaredField("data");
        data.setAccessible(true);
        data.set(null, DICTIONARY);
        ScriptModule module = new ScriptModule();
        module.name = "C51";
        ScriptManager.instance.moduleMap.put("C51", module);
        FixtureItem bagDefinition = new FixtureItem(module, "Bag", "bag", (short) 1);
        FixtureItem keyDefinition = new FixtureItem(module, "Key", "key", (short) 2);
        FixtureItem foodDefinition = new FixtureItem(module, "Food", "food", (short) 3);
        FixtureItem weaponDefinition = new FixtureItem(module, "Weapon", "weapon", (short) 4);

        IsoPlayer source = person();
        InventoryContainer bag = (InventoryContainer) bagDefinition.InstanceItem(null, false);
        Key key = (Key) keyDefinition.InstanceItem(null, false);
        key.setKeyId(67890);
        key.getModData().rawset("fixture", "private-key-state");
        Food food = (Food) foodDefinition.InstanceItem(null, false);
        Food rootFood = (Food) foodDefinition.InstanceItem(null, false);
        rootFood.setAge(4.5f);
        food.setHungChange(-.37f);
        food.setAge(2.75f);
        food.setPoisonPower(9);
        HandWeapon first = (HandWeapon) weaponDefinition.InstanceItem(null, false);
        HandWeapon second = (HandWeapon) weaponDefinition.InstanceItem(null, false);
        first.setCondition(3);
        second.setCondition(7);
        second.setCurrentAmmoCount(4);
        bag.getInventory().AddItem(key);
        bag.getInventory().AddItem(food);
        source.getInventory().AddItem(bag);
        source.getInventory().AddItem(first);
        source.getInventory().AddItem(second);
        source.getInventory().AddItem(rootFood);
        source.setPrimaryHandItem(second);
        source.setSecondaryHandItem(second);
        source.setWornItem(ItemBodyLocation.BACK, bag);
        source.setAttachedItem("FixtureSlot", first);
        source.getStats().set(CharacterStat.HUNGER, .42f);
        source.getStats().set(CharacterStat.PANIC, 37f);
        var wound = source.getBodyDamage().getBodyPart(BodyPartType.Hand_R);
        wound.SetHealth(63f);
        wound.setBandaged(true, 4.25f, true, "fixture-bandage");
        wound.setBiteTime(12.5f);
        wound.setWoundInfectionLevel(2.5f);
        source.getXp().xpMap.put(PerkFactory.Perks.Aiming, 88.5f);
        source.setPerkLevelDebug(PerkFactory.Perks.Aiming, 2);
        source.getCharacterTraits().set(CharacterTrait.SMOKER, true);
        source.getCharacterTraits().set(customTrait, true);
        source.getXp().xpMap.put(earnedPerk, 12.75f);
        source.setPerkLevelDebug(levelPerk, 3);
        source.getXp().addXpMultiplier(multiplierPerk, 1.75f, 2, 6);

        String packed = SAONativeSnapshot.capture(source);
        check(SAONativeSnapshot.validate(packed), "captured snapshot refused");
        check(source.getInventory().getItems().size() == 4, "capture mutated source inventory");
        check(source.getPrimaryHandItem() == second, "capture changed held object");
        // Empty native cell, with no chunks/world/save loaded. The constructor
        // starts a reuse worker; stop it immediately before exercising queues.
        zombie.iso.IsoCell cell = new zombie.iso.IsoCell(1, 1);
        zombie.iso.WorldReuserThread.instance.stop();
        IsoPlayer restored = person();
        check(SAONativeSnapshot.restore(restored, packed) == 6, "item count");
        InventoryContainer restoredBag = (InventoryContainer) restored.getWornItem(ItemBodyLocation.BACK);
        check(restoredBag != null && restoredBag.id == bag.id, "worn bag identity");
        check(restoredBag.getInventory().getItems().size() == 2, "nested contents");
        Key restoredKey = (Key) restoredBag.getInventory().getItems().stream()
                .filter(item -> item instanceof Key).findFirst().orElseThrow();
        Food restoredFood = (Food) restoredBag.getInventory().getItems().stream()
                .filter(item -> item instanceof Food).findFirst().orElseThrow();
        check(restoredKey.getKeyId() == 67890, "key lock identity");
        check("private-key-state".equals(restoredKey.getModData().rawget("fixture")), "item modData");
        check(restoredFood.getAge() == 2.75f && restoredFood.getHungChange() == -.37f
                && restoredFood.getPoisonPower() == 9, "food instance state");
        InventoryItem restoredRootFood = restored.getInventory().getItems().stream()
                .filter(item -> item.id == rootFood.id).findFirst().orElseThrow();
        check(cell.getProcessItems().contains(restoredFood)
                && cell.getProcessItems().contains(restoredRootFood),
                "root and nested food not registered for native processing");
        check(restored.getPrimaryHandItem().id == second.id
                && restored.getSecondaryHandItem() == restored.getPrimaryHandItem()
                && restored.getPrimaryHandItem().getCondition() == 7
                && restored.getPrimaryHandItem().getCurrentAmmoCount() == 4,
                "same-type equipment identity/ammunition");
        check(restored.getAttachedItems().getItem("FixtureSlot").id == first.id,
                "attached item identity");
        check(restored.getStats().get(CharacterStat.HUNGER) == .42f
                && restored.getStats().get(CharacterStat.PANIC) == 37f, "native stats");
        var restoredWound = restored.getBodyDamage().getBodyPart(BodyPartType.Hand_R);
        check(restoredWound.getHealth() == 63f && restoredWound.bandaged()
                && restoredWound.getBandageLife() == 4.25f
                && restoredWound.getBiteTime() == 12.5f
                && restoredWound.getWoundInfectionLevel() == 2.5f, "native wound state");
        check(restored.getXp().getXP(PerkFactory.Perks.Aiming) == 88.5f
                && restored.getPerkLevel(PerkFactory.Perks.Aiming) == 2
                && restored.getCharacterTraits().get(CharacterTrait.SMOKER), "native XP and traits");
        check(restored.getXp().getXP(earnedPerk) == 12.75f
                && restored.getPerkLevel(levelPerk) == 3
                && restored.getXp().getMultiplierMap().get(multiplierPerk).multiplier == 1.75f
                && restored.getXp().getMultiplierMap().get(multiplierPerk).minLevel == 2
                && restored.getXp().getMultiplierMap().get(multiplierPerk).maxLevel == 6
                && restored.getCharacterTraits().get(customTrait), "custom XP channels and trait");
        SAONativeSnapshot.unregister(restored);
        SAONativeSnapshot.unregister(restored);
        check(cell.getProcessItemsRemove().size() == 6
                && cell.getProcessItemsRemove().contains(restoredFood)
                && cell.getProcessItemsRemove().contains(restoredRootFood),
                "recursive native processing removal");
        missingPerkRefused(packed, earnedPerk);
        missingPerkRefused(packed, levelPerk);
        missingPerkRefused(packed, multiplierPerk);
        missingTraitRefused(packed, customTrait);
        check(!SAONativeSnapshot.validate(packed.substring(0, packed.length() - 4)), "truncation accepted");
        byte[] damaged = Base64.getDecoder().decode(packed.substring(3));
        damaged[30] ^= 1;
        check(!SAONativeSnapshot.validate("v3;" + Base64.getEncoder().encodeToString(damaged)),
                "checksum corruption accepted");
        check(!SAONativeSnapshot.validate(alteredVersion(packed)), "unsupported native version accepted");
        check(!SAONativeSnapshot.validate("v3;%%invalid"), "bad Base64 accepted");
        DICTIONARY.missing((short) 2);
        boolean refused = false;
        try { SAONativeSnapshot.restore(person(), packed); }
        catch (Exception expected) { refused = true; }
        check(refused, "missing nested unequipped script accepted");
        System.out.println("PASS native snapshot: 6 items; nested key/food/modData; exact hands/worn/attached; "
                + "native item processing/removal; stats/wounds/XP/traits; "
                + "corruption/version/missing-nested-script/custom-perk/custom-trait controls");
    }
}
