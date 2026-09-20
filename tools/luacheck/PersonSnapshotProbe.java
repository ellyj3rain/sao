import com.sao.engine.SAONativeSnapshot;
import com.sao.engine.SAOHibernation;
import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.DataInputStream;
import java.io.DataOutputStream;
import java.lang.reflect.Field;
import java.lang.reflect.Method;
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
import zombie.entity.Component;
import zombie.entity.GameEntity;
import zombie.entity.components.fluids.Fluid;
import zombie.entity.components.fluids.FluidContainer;
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
        desc.setFemale(false);
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
        return packed.substring(0, 3) + Base64.getEncoder().encodeToString(bytes);
    }

    private static Field field(Class<?> type, String name) throws Exception {
        Field value = type.getDeclaredField(name);
        value.setAccessible(true);
        return value;
    }

    @SuppressWarnings("unchecked")
    private static <T> T value(Object owner, Class<?> type, String name) throws Exception {
        return (T) field(type, name).get(owner);
    }

    private static void set(Object owner, Class<?> type, String name, Object value) throws Exception {
        field(type, name).set(owner, value);
    }

    private static void attachFluid(InventoryItem item, Fluid... fluids) throws Exception {
        FluidContainer container = FluidContainer.CreateContainer();
        container.setCapacity(4.0f);
        for (int i = 0; i < fluids.length; i++) container.addFluid(fluids[i], .4f + i * .3f);
        Method add = GameEntity.class.getDeclaredMethod("addComponent", Component.class);
        add.setAccessible(true);
        check((Boolean) add.invoke(item, container), "fluid component fixture attachment");
    }

    private static InventoryItem fixtureRole(zombie.inventory.ItemContainer container,
            String role) {
        for (InventoryItem item : container.getItems()) {
            if (role.equals(item.getModData().rawget("fixtureRole"))) return item;
            if (item instanceof InventoryContainer nested) {
                InventoryItem found = fixtureRole(nested.getInventory(), role);
                if (found != null) return found;
            }
        }
        return null;
    }

    private static String downgradeV3(String packed) throws Exception {
        byte[] encoded = Base64.getDecoder().decode(packed.substring(3));
        int payloadLength = encoded.length - 32;
        byte[][] sections = new byte[5][];
        try (DataInputStream in = new DataInputStream(
                new ByteArrayInputStream(encoded, 0, payloadLength))) {
            in.readInt(); in.readInt(); in.readInt();
            check(in.readInt() == 10, "v4 section count");
            for (int i = 0; i < 5; i++) sections[i] = in.readNBytes(in.readInt());
        }
        // v3's manifest ended after equipment. A no-fluid v4 manifest carries
        // only the appended zero count, which is removed for this fixture.
        check(ByteBuffer.wrap(sections[4], sections[4].length - 4, 4).getInt() == 0,
                "legacy fixture unexpectedly has fluid facts");
        sections[4] = Arrays.copyOf(sections[4], sections[4].length - 4);
        ByteArrayOutputStream payload = new ByteArrayOutputStream();
        try (DataOutputStream out = new DataOutputStream(payload)) {
            out.writeInt(0x53414f33); out.writeInt(1); out.writeInt(249); out.writeInt(5);
            for (byte[] section : sections) { out.writeInt(section.length); out.write(section); }
        }
        byte[] digest = MessageDigest.getInstance("SHA-256").digest(payload.toByteArray());
        payload.write(digest);
        return "v3;" + Base64.getEncoder().encodeToString(payload.toByteArray());
    }

    private static String mutateSectionFloat(String packed, int sectionIndex,
            int offset, float value) throws Exception {
        byte[] encoded = Base64.getDecoder().decode(packed.substring(3));
        int payloadLength = encoded.length - 32;
        byte[][] sections;
        int magic, format, world, count;
        try (DataInputStream in = new DataInputStream(
                new ByteArrayInputStream(encoded, 0, payloadLength))) {
            magic = in.readInt(); format = in.readInt(); world = in.readInt(); count = in.readInt();
            sections = new byte[count][];
            for (int i = 0; i < count; i++) sections[i] = in.readNBytes(in.readInt());
        }
        ByteBuffer.wrap(sections[sectionIndex]).putFloat(offset, value);
        ByteArrayOutputStream payload = new ByteArrayOutputStream();
        try (DataOutputStream out = new DataOutputStream(payload)) {
            out.writeInt(magic); out.writeInt(format); out.writeInt(world); out.writeInt(count);
            for (byte[] section : sections) { out.writeInt(section.length); out.write(section); }
        }
        payload.write(MessageDigest.getInstance("SHA-256").digest(payload.toByteArray()));
        return packed.substring(0, 3) + Base64.getEncoder().encodeToString(payload.toByteArray());
    }

    @SuppressWarnings("unchecked")
    private static void missingFluidRefused(String packed) throws Exception {
        Field registryField = Fluid.class.getDeclaredField("fluidEnumMap");
        registryField.setAccessible(true);
        var registry = (java.util.Map<zombie.entity.components.fluids.FluidType, Fluid>)
                registryField.get(null);
        var type = Fluid.Beer.getFluidType();
        Fluid prior = registry.remove(type);
        try {
            boolean refused = false;
            try { SAONativeSnapshot.restoreStaged(person(), packed); }
            catch (Exception expected) { refused = true; }
            check(refused, "missing fluid definition accepted");
        } finally {
            registry.put(type, prior);
        }
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
        var fixtureHair = new zombie.core.skinnedmodel.population.HairStyle();
        fixtureHair.name = "C54Hair"; fixtureHair.model = "C54HairModel";
        fixtureHair.texture = "C54HairTexture";
        zombie.core.skinnedmodel.population.HairStyles.instance.maleStyles.add(fixtureHair);
        zombie.core.skinnedmodel.population.HairStyles.instance.femaleStyles.add(fixtureHair);
        var fixtureBeard = new zombie.core.skinnedmodel.population.BeardStyle();
        fixtureBeard.name = "C54Beard"; fixtureBeard.model = "C54BeardModel";
        fixtureBeard.texture = "C54BeardTexture";
        zombie.core.skinnedmodel.population.BeardStyles.instance.styles.add(fixtureBeard);
        zombie.core.skinnedmodel.population.OutfitManager.instance =
                new zombie.core.skinnedmodel.population.OutfitManager();
        var fixtureOutfit = new zombie.core.skinnedmodel.population.Outfit();
        fixtureOutfit.name = "C54Outfit";
        zombie.core.skinnedmodel.population.OutfitManager.instance.maleOutfits.add(fixtureOutfit);
        zombie.core.skinnedmodel.population.OutfitManager.instance.femaleOutfits.add(fixtureOutfit);
        java.util.Map<String, zombie.core.skinnedmodel.population.Outfit> maleOutfitMap = value(
                zombie.core.skinnedmodel.population.OutfitManager.instance,
                zombie.core.skinnedmodel.population.OutfitManager.class, "maleOutfitMap");
        java.util.Map<String, zombie.core.skinnedmodel.population.Outfit> femaleOutfitMap = value(
                zombie.core.skinnedmodel.population.OutfitManager.instance,
                zombie.core.skinnedmodel.population.OutfitManager.class, "femaleOutfitMap");
        maleOutfitMap.put(fixtureOutfit.name, fixtureOutfit);
        femaleOutfitMap.put(fixtureOutfit.name, fixtureOutfit);
        zombie.GameTime.setInstance(new zombie.GameTime());
        zombie.GameTime.getInstance().updateCalendar(1993, 0, 1, 12, 0);
        zombie.characters.WornItems.BodyLocations.getGroup("Human")
                .getOrCreateLocation(ItemBodyLocation.BACK);
        zombie.characters.AttachedItems.AttachedLocations.getGroup("Human")
                .getOrCreateLocation("FixtureSlot");
        PerkFactory.init();
        var earnedPerk = new PerkFactory.Perk("C51Earned");
        var levelPerk = new PerkFactory.Perk("C51Level");
        var multiplierPerk = new PerkFactory.Perk("C51Multiplier");
        var boostPerk = new PerkFactory.Perk("C54BoostOnly");
        CharacterTrait customTrait = CharacterTrait.register("C51:FixtureTrait");
        var waterProperties = new zombie.entity.components.fluids.FluidProperties();
        waterProperties.setThirstChange(-1.0f);
        set(Fluid.Water, Fluid.class, "properties",
                waterProperties.getSealedFluidProperties());
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
        attachFluid(rootFood, Fluid.Water, Fluid.Beer);
        attachFluid(food, Fluid.TaintedWater);

        source.getNutrition().setCalories(1450.25f);
        source.getNutrition().setProteins(83.5f);
        source.getNutrition().setLipids(44.25f);
        source.getNutrition().setCarbohydrates(206.75f);
        source.getNutrition().setWeight(79.5);
        source.getNutrition().setIncWeight(true);
        source.getNutrition().setIncWeightLot(false);
        source.getNutrition().setDecWeight(true);
        set(source.getNutrition(), zombie.characters.BodyDamage.Nutrition.class, "updatedWeight", 17);
        set(source.getNutrition(), zombie.characters.BodyDamage.Nutrition.class, "caloriesMax", 1925.5f);
        set(source.getNutrition(), zombie.characters.BodyDamage.Nutrition.class, "caloriesMin", -415.25f);

        var fitness = source.getFitness();
        fitness.getRegularityMap().put("pushups", .73f);
        java.util.Map<String, Integer> stiffnessTimers = value(fitness,
                zombie.characters.BodyDamage.Fitness.class, "stiffnessTimerMap");
        java.util.Map<String, Float> stiffnessInc = value(fitness,
                zombie.characters.BodyDamage.Fitness.class, "stiffnessIncMap");
        java.util.List<String> affectedParts = value(fitness,
                zombie.characters.BodyDamage.Fitness.class, "bodypartToIncStiffness");
        java.util.Map<String, Long> exerciseTimes = value(fitness,
                zombie.characters.BodyDamage.Fitness.class, "exeTimer");
        stiffnessTimers.put("arms", 2);
        stiffnessInc.put("arms", .6f);
        affectedParts.add("arms");
        exerciseTimes.put("pushups", 123456789L);
        set(fitness, zombie.characters.BodyDamage.Fitness.class, "lastUpdate", 99);
        var exerciseTable = (se.krka.kahlua.j2se.KahluaTableImpl)
                zombie.Lua.LuaManager.platform.newTable();
        exerciseTable.rawset("type", "pushups");
        exerciseTable.rawset("metabolics", null);
        exerciseTable.rawset("stiffness", "arms");
        exerciseTable.rawset("xpMod", 1.0d);
        set(fitness, zombie.characters.BodyDamage.Fitness.class, "currentExe",
                new zombie.characters.BodyDamage.Fitness.FitnessExercise(exerciseTable));
        check(fitness.getCurrentExe() != null, "fitness action fixture did not start");

        source.getKnownRecipes().add("C54.MissingRecipeStillKnown");
        source.addKnownMediaLine("C54.Media.Line");
        source.setAlreadyReadPages("C54.Book", 37);
        source.getAlreadyReadBook().add("C54.CompletedBook");
        source.getReadLiterature().put("C54.Literature", 3);
        source.getReadPrintMedia().add("C54.Print");
        source.getDescriptor().getXPBoostMap().put(boostPerk, 2);
        set(source, zombie.characters.IsoGameCharacter.class, "beardGrowTiming", 22.5f);
        set(source, zombie.characters.IsoGameCharacter.class, "hairGrowTiming", 41.75f);
        source.getHumanVisual().setSkinTextureName("c54-skin");
        source.getHumanVisual().setHairModel("C54Hair");
        source.getHumanVisual().setBeardModel("C54Beard");
        source.getHumanVisual().setHairColor(new zombie.core.ImmutableColor(.11f, .22f, .33f));
        source.getHumanVisual().setOutfit(fixtureOutfit);

        var treatment = zombie.Lua.LuaManager.platform.newTable();
        treatment.rawset("dose", 2.5d);
        treatment.rawset("active", true);
        source.getModData().rawset("NnCMethadoneEffect", treatment);
        source.getModData().rawset("DurableLabel", "C54 durable");
        source.getModData().rawset("SAOPersonId", "source-runtime-id");

        for (String safe : new String[]{"a".repeat(32767), "\u00e9".repeat(16383) + "a"}) {
            key.getModData().rawset("boundary", safe);
            IsoPlayer boundary = person();
            SAONativeSnapshot.restoreStaged(boundary, SAONativeSnapshot.capture(source));
            InventoryContainer boundaryBag = (InventoryContainer) boundary.getWornItem(ItemBodyLocation.BACK);
            Key boundaryKey = (Key) boundaryBag.getInventory().getItems().stream()
                    .filter(item -> item instanceof Key).findFirst().orElseThrow();
            check(safe.equals(boundaryKey.getModData().rawget("boundary")) && boundaryKey.getKeyId() == 67890,
                    "safe native item string boundary changed");
        }
        key.getModData().rawset("boundary", null);
        for (String oversized : new String[]{"a".repeat(32768), "a".repeat(65536), "\u00e9".repeat(16384)}) {
            key.getModData().rawset("oversized", oversized);
            boolean rejected = false;
            try { SAONativeSnapshot.capture(source); }
            catch (java.io.IOException expected) { rejected = expected.getMessage().contains("native byte limit"); }
            check(rejected, "oversized native item string accepted");
            check(oversized.equals(key.getModData().rawget("oversized")) && key.getKeyId() == 67890,
                    "refused native item capture changed source");
        }
        key.getModData().rawset("oversized", null);
        var nestedTable = zombie.Lua.LuaManager.platform.newTable();
        nestedTable.rawset("nested", "a".repeat(32768)); key.getModData().rawset("table", nestedTable);
        boolean nestedRejected = false;
        try { SAONativeSnapshot.capture(source); } catch (java.io.IOException expected) { nestedRejected = true; }
        check(nestedRejected, "oversized nested item string accepted");
        nestedTable.rawset("nested", null); nestedTable.rawset("self", nestedTable);
        boolean cyclicRejected = false;
        try { SAONativeSnapshot.capture(source); } catch (java.io.IOException expected) { cyclicRejected = true; }
        check(cyclicRejected, "cyclic item ModData accepted");
        key.getModData().rawset("table", null);
        String oversizedKey = "a".repeat(32768); key.getModData().rawset(oversizedKey, "value");
        boolean keyRejected = false;
        try { SAONativeSnapshot.capture(source); } catch (java.io.IOException expected) { keyRejected = true; }
        check(keyRejected, "oversized item table key accepted");
        key.getModData().rawset(oversizedKey, null);

        // Hand-check the motivating engine defect independently of our guard:
        // a native load can succeed while interpreting string bytes as key ID.
        Key unsafeKey = (Key) keyDefinition.InstanceItem(null, false);
        unsafeKey.setKeyId(67890); unsafeKey.getModData().rawset("oversized", "a".repeat(32768));
        var unsafeInventory = new zombie.inventory.ItemContainer(); unsafeInventory.AddItem(unsafeKey);
        ByteBuffer unsafeBytes = ByteBuffer.allocate(1024 * 1024);
        unsafeInventory.save(unsafeBytes); unsafeBytes.flip();
        var unsafeLoaded = new zombie.inventory.ItemContainer(); unsafeLoaded.load(unsafeBytes, zombie.iso.IsoWorld.getWorldVersion());
        Key unsafeRestored = (Key) unsafeLoaded.getItems().get(0);
        check(unsafeRestored.getKeyId() != 67890, "native oversized-string motivating defect changed");
        System.out.println("ENGINE oversized native item string: load succeeds, keyId 67890 -> " + unsafeRestored.getKeyId());

        source.getModData().rawset("UnsupportedDurable", new Object());
        boolean unsupportedCharacterData = false;
        try { SAONativeSnapshot.capture(source); }
        catch (java.io.IOException expected) {
            unsupportedCharacterData = expected.getMessage().contains("Unsupported durable");
        }
        check(unsupportedCharacterData, "unsupported durable character ModData accepted");
        source.getModData().rawset("UnsupportedDurable", null);
        var cyclicCharacterData = zombie.Lua.LuaManager.platform.newTable();
        cyclicCharacterData.rawset("self", cyclicCharacterData);
        source.getModData().rawset("CyclicDurable", cyclicCharacterData);
        boolean cyclicCharacterRejected = false;
        try { SAONativeSnapshot.capture(source); }
        catch (java.io.IOException expected) { cyclicCharacterRejected = true; }
        check(cyclicCharacterRejected, "cyclic durable character ModData accepted");
        source.getModData().rawset("CyclicDurable", null);
        source.getModData().rawset("OversizedDurable", "x".repeat(32768));
        boolean oversizedCharacterRejected = false;
        try { SAONativeSnapshot.capture(source); }
        catch (java.io.IOException expected) { oversizedCharacterRejected = true; }
        check(oversizedCharacterRejected, "oversized durable character ModData accepted");
        source.getModData().rawset("OversizedDurable", null);
        // Runtime ownership keys are reconstructed by their owners and may
        // carry values outside the durable table codec.
        source.getModData().rawset("SAOPersonId", new Object());

        String packed = SAONativeSnapshot.capture(source);
        check(SAONativeSnapshot.validate(packed) && SAONativeSnapshot.formatVersion(packed) == 4,
                "captured v4 snapshot refused");
        String lowWeight = mutateSectionFloat(packed, 5, 16, 34f);
        check(!SAONativeSnapshot.validate(lowWeight), "unsafe nutrition weight accepted");
        IsoPlayer endangered = person();
        float healthBeforeUnsafeRestore = endangered.getBodyDamage().getHealth();
        boolean unsafeRestoreRefused = false;
        try { SAONativeSnapshot.restoreStaged(endangered, lowWeight); }
        catch (Exception expected) { unsafeRestoreRefused = true; }
        check(unsafeRestoreRefused
                && endangered.getBodyDamage().getHealth() == healthBeforeUnsafeRestore,
                "unsafe nutrition preflight mutated destination");
        missingFluidRefused(packed);
        check(source.getInventory().getItems().size() == 4, "capture mutated source inventory");
        check(source.getPrimaryHandItem() == second, "capture changed held object");
        // Empty native cell, with no chunks/world/save loaded. The constructor
        // starts a reuse worker; stop it immediately before exercising queues.
        zombie.iso.IsoCell cell = new zombie.iso.IsoCell(1, 1);
        zombie.iso.WorldReuserThread.instance.stop();
        IsoPlayer restored = person();
        restored.getModData().rawset("SAOPersonId", "destination-runtime-id");
        restored.getFitness().getRegularityMap().put("stale-destination", .9f);
        ((java.util.List<String>) value(restored.getFitness(),
                zombie.characters.BodyDamage.Fitness.class, "bodypartToIncStiffness"))
                .add("stale-destination");
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
        check(Math.abs(restoredRootFood.getFluidContainer().getAmount() - 1.1f) < .0001f
                && Math.abs(restoredRootFood.getFluidContainer().getSpecificFluidAmount(Fluid.Water) - .4f) < .0001f
                && Math.abs(restoredRootFood.getFluidContainer().getSpecificFluidAmount(Fluid.Beer) - .7f) < .0001f
                && Math.abs(restoredFood.getFluidContainer().getSpecificFluidAmount(Fluid.TaintedWater) - .4f) < .0001f,
                "root and nested fluid mixture");
        check(restored.getNutrition().getCalories() == 1450.25f
                && restored.getNutrition().getProteins() == 83.5f
                && restored.getNutrition().getLipids() == 44.25f
                && restored.getNutrition().getCarbohydrates() == 206.75f
                && restored.getNutrition().getWeight() == 79.5
                && (Integer) value(restored.getNutrition(), zombie.characters.BodyDamage.Nutrition.class,
                    "updatedWeight") == 17
                && (Float) value(restored.getNutrition(), zombie.characters.BodyDamage.Nutrition.class,
                    "caloriesMax") == 1925.5f
                && (Float) value(restored.getNutrition(), zombie.characters.BodyDamage.Nutrition.class,
                    "caloriesMin") == -415.25f
                && restored.getNutrition().isIncWeight() && restored.getNutrition().isDecWeight(),
                "nutrition continuation state");
        var restoredFitness = restored.getFitness();
        check(restoredFitness.getRegularity("pushups") == .73f
                && ((java.util.Map<String, Integer>) value(restoredFitness,
                    zombie.characters.BodyDamage.Fitness.class, "stiffnessTimerMap")).get("arms") == 2
                && ((java.util.Map<String, Float>) value(restoredFitness,
                    zombie.characters.BodyDamage.Fitness.class, "stiffnessIncMap")).get("arms") == .6f
                && ((java.util.List<String>) value(restoredFitness,
                    zombie.characters.BodyDamage.Fitness.class, "bodypartToIncStiffness")).contains("arms")
                && ((java.util.Map<String, Long>) value(restoredFitness,
                    zombie.characters.BodyDamage.Fitness.class, "exeTimer")).get("pushups") == 123456789L
                && !restoredFitness.getRegularityMap().containsKey("stale-destination")
                && !((java.util.List<String>) value(restoredFitness,
                    zombie.characters.BodyDamage.Fitness.class, "bodypartToIncStiffness"))
                    .contains("stale-destination")
                && restoredFitness.getCurrentExe() == null
                && (Integer) value(restoredFitness, zombie.characters.BodyDamage.Fitness.class,
                    "lastUpdate") == -1,
                "fitness continuation state, cancelled action and fresh update baseline");
        check(restored.getKnownRecipes().contains("C54.MissingRecipeStillKnown")
                && restored.isKnownMediaLine("C54.Media.Line")
                && restored.getAlreadyReadPages("C54.Book") == 37
                && restored.getAlreadyReadBook().contains("C54.CompletedBook")
                && restored.getReadLiterature().get("C54.Literature") == 3
                && restored.getReadPrintMedia().contains("C54.Print")
                && restored.getDescriptor().getXPBoostMap().get(boostPerk) == 2,
                "recipe reading media and descriptor boost state");
        check("c54-skin".equals(value(restored.getHumanVisual(),
                    zombie.core.skinnedmodel.visual.HumanVisual.class, "skinTextureName")),
                "human skin texture");
        check("C54Hair".equals(restored.getHumanVisual().getHairModel()), "human hair model");
        check("C54Beard".equals(restored.getHumanVisual().getBeardModel()), "human beard model");
        check(restored.getHumanVisual().getOutfit() == fixtureOutfit, "human outfit reference");
        check((Float) value(restored, zombie.characters.IsoGameCharacter.class,
                    "beardGrowTiming") == 22.5f
                && (Float) value(restored, zombie.characters.IsoGameCharacter.class,
                    "hairGrowTiming") == 41.75f,
                "human hair growth timing");
        var restoredTreatment = (se.krka.kahlua.vm.KahluaTable)
                restored.getModData().rawget("NnCMethadoneEffect");
        check(restoredTreatment != null, "durable character ModData and runtime ownership");
        check(restoredTreatment != treatment
                && restoredTreatment.rawget("dose").equals(2.5d)
                && restoredTreatment.rawget("active").equals(true)
                && "C54 durable".equals(restored.getModData().rawget("DurableLabel"))
                && "destination-runtime-id".equals(restored.getModData().rawget("SAOPersonId")),
                "durable character ModData and runtime ownership");

        String repeatedPacked = SAONativeSnapshot.capture(restored);
        IsoPlayer repeated = person();
        repeated.getModData().rawset("SAOPersonId", "second-runtime-id");
        check(SAONativeSnapshot.restoreStaged(repeated, repeatedPacked) == 6,
                "repeated wake item count");
        var repeatedTreatment = (se.krka.kahlua.vm.KahluaTable)
                repeated.getModData().rawget("NnCMethadoneEffect");
        restoredTreatment.rawset("dose", 9.0d);
        check(repeatedTreatment.rawget("dose").equals(2.5d)
                && "second-runtime-id".equals(repeated.getModData().rawget("SAOPersonId"))
                && repeated.getAlreadyReadPages("C54.Book") == 37
                && repeated.getFitness().getRegularity("pushups") == .73f
                && repeated.getFitness().getCurrentExe() == null,
                "repeated wake, cancelled action and ModData alias isolation");

        zombie.GameTime.getInstance().updateCalendar(1993, 0, 1, 12, 0);
        restored.getFitness().update();
        repeated.getFitness().update();
        check((Integer) value(restored.getFitness(), zombie.characters.BodyDamage.Fitness.class,
                    "lastUpdate") == 0
                && (Integer) value(repeated.getFitness(), zombie.characters.BodyDamage.Fitness.class,
                    "lastUpdate") == 0,
                "fitness first update establishes current baseline");
        zombie.GameTime.getInstance().updateCalendar(1993, 0, 1, 12, 10);
        restored.getFitness().update();
        repeated.getFitness().update();
        check(((java.util.Map<String, Integer>) value(restored.getFitness(),
                    zombie.characters.BodyDamage.Fitness.class, "stiffnessTimerMap")).equals(
                (java.util.Map<String, Integer>) value(repeated.getFitness(),
                    zombie.characters.BodyDamage.Fitness.class, "stiffnessTimerMap"))
                && restored.getFitness().getRegularityMap().equals(repeated.getFitness().getRegularityMap()),
                "fitness next update differs after repeated wake");
        restored.getNutrition().update();
        repeated.getNutrition().update();
        check(restored.getNutrition().getCalories() == repeated.getNutrition().getCalories()
                && restored.getNutrition().getWeight() == repeated.getNutrition().getWeight()
                && restored.getNutrition().isIncWeight() == repeated.getNutrition().isIncWeight(),
                "nutrition next update differs after repeated wake");
        float beforeRestored = restored.getXp().getXP(boostPerk);
        float beforeRepeated = repeated.getXp().getXP(boostPerk);
        restored.getXp().AddXP(boostPerk, 10f, false, false);
        repeated.getXp().AddXP(boostPerk, 10f, false, false);
        check(restored.getXp().getXP(boostPerk) - beforeRestored
                == repeated.getXp().getXP(boostPerk) - beforeRepeated,
                "next boosted XP grant differs after wake");

        // Dormant resource reconciliation uses the engine's actual partial
        // Eat/DrinkFluid paths, including nested containers and nutrition.
        IsoPlayer dormant = person();
        InventoryContainer provisions =
                (InventoryContainer) bagDefinition.InstanceItem(null, false);
        Food ration = (Food) foodDefinition.InstanceItem(null, false);
        ration.setBaseHunger(-.80f); ration.setHungChange(-.80f);
        ration.setCalories(800f); ration.setCarbohydrates(100f);
        ration.setProteins(30f); ration.setLipids(20f);
        ration.getModData().rawset("fixtureRole", "ration");
        Food canteen = (Food) foodDefinition.InstanceItem(null, false);
        canteen.setBaseHunger(0f); canteen.setHungChange(0f);
        canteen.getModData().rawset("fixtureRole", "canteen");
        attachFluid(canteen, Fluid.Water);
        canteen.getFluidContainer().addFluid(Fluid.Water, 3.0f);
        Food rotten = (Food) foodDefinition.InstanceItem(null, false);
        rotten.setBaseHunger(-1f); rotten.setHungChange(-1f);
        rotten.setOffAge(1); rotten.setOffAgeMax(2); rotten.setAge(3f);
        rotten.setCalories(1200f);
        rotten.getModData().rawset("fixtureRole", "rotten");
        provisions.getInventory().AddItem(ration);
        provisions.getInventory().AddItem(canteen);
        dormant.getInventory().AddItem(provisions);
        dormant.getInventory().AddItem(rotten);
        dormant.getStats().set(CharacterStat.HUNGER, .40f);
        dormant.getStats().set(CharacterStat.THIRST, .40f);
        dormant.getNutrition().setCalories(1000f);
        String dormantPacked = SAONativeSnapshot.capture(dormant);

        IsoPlayer zero = person();
        String zeroJournal = SAOHibernation.awaken(zero, dormantPacked, 0);
        Food zeroRation = (Food) fixtureRole(zero.getInventory(), "ration");
        InventoryItem zeroCanteen = fixtureRole(zero.getInventory(), "canteen");
        Food zeroRotten = (Food) fixtureRole(zero.getInventory(), "rotten");
        check(zeroJournal.startsWith("AWAKENED ")
                && zero.getStats().get(CharacterStat.HUNGER) == .40f
                && zero.getStats().get(CharacterStat.THIRST) == .40f
                && zeroRation.getHungChange() == -.80f
                && Math.abs(zeroCanteen.getFluidContainer().getAmount() - 3.4f) < .0001f
                && zero.getNutrition().getCalories() == 1000f,
                "zero elapsed dormant wake changed resources or physiology");

        IsoPlayer whole = person();
        String wholeJournal = SAOHibernation.awaken(whole, dormantPacked, 20);
        IsoPlayer firstHalf = person();
        check(SAOHibernation.awaken(firstHalf, dormantPacked, 10).startsWith("AWAKENED "),
                "first partition wake failed");
        String middle = SAOHibernation.hibernate(firstHalf);
        IsoPlayer partitioned = person();
        String secondJournal = SAOHibernation.awaken(partitioned, middle, 10);
        Food wholeRation = (Food) fixtureRole(whole.getInventory(), "ration");
        Food splitRation = (Food) fixtureRole(partitioned.getInventory(), "ration");
        InventoryItem wholeCanteen = fixtureRole(whole.getInventory(), "canteen");
        InventoryItem splitCanteen = fixtureRole(partitioned.getInventory(), "canteen");
        Food wholeRotten = (Food) fixtureRole(whole.getInventory(), "rotten");
        check(wholeRotten != null
                && wholeRotten.getHungChange() == zeroRotten.getHungChange(),
                "rotten food was consumed");
        check(wholeRation != null && splitRation != null
                && wholeRation.getHungChange() < 0f
                && Math.abs(wholeRation.getHungChange()) < .80f,
                "partial nested food quantity was not retained");
        check(wholeCanteen != null && splitCanteen != null
                && wholeCanteen.getFluidContainer().getAmount() > 0f
                && wholeCanteen.getFluidContainer().getAmount() < 3.4f,
                "partial nested drink quantity was not retained");
        check(whole.getNutrition().getCalories() > 1000f,
                "native eating did not reconcile nutrition");
        check(Math.abs(whole.getStats().get(CharacterStat.HUNGER)
                    - partitioned.getStats().get(CharacterStat.HUNGER)) < .0002f
                && Math.abs(whole.getStats().get(CharacterStat.THIRST)
                    - partitioned.getStats().get(CharacterStat.THIRST)) < .0002f
                && Math.abs(wholeRation.getHungChange()
                    - splitRation.getHungChange()) < .0002f
                && Math.abs(wholeCanteen.getFluidContainer().getAmount()
                    - splitCanteen.getFluidContainer().getAmount()) < .0002f
                && Math.abs(whole.getNutrition().getCalories()
                    - partitioned.getNutrition().getCalories()) < .02f,
                "equal dormant event history changed across interval partitions");
        check(wholeJournal.contains("foodHunger=")
                && wholeJournal.contains("fluidConsumed=")
                && wholeJournal.contains("caloriesDormant=")
                && secondJournal.contains("foodHunger="),
                "dormant resource quantities absent from journal");

        zombie.core.skinnedmodel.population.OutfitManager.instance.maleOutfits.remove(fixtureOutfit);
        zombie.core.skinnedmodel.population.OutfitManager.instance.femaleOutfits.remove(fixtureOutfit);
        maleOutfitMap.remove(fixtureOutfit.name);
        femaleOutfitMap.remove(fixtureOutfit.name);
        boolean missingOutfit = false;
        try { SAONativeSnapshot.restoreStaged(person(), packed); }
        catch (java.io.IOException expected) { missingOutfit = expected.getMessage().contains("Outfit unavailable"); }
        check(missingOutfit, "missing outfit reference accepted");
        zombie.core.skinnedmodel.population.OutfitManager.instance.maleOutfits.add(fixtureOutfit);
        zombie.core.skinnedmodel.population.OutfitManager.instance.femaleOutfits.add(fixtureOutfit);
        maleOutfitMap.put(fixtureOutfit.name, fixtureOutfit);
        femaleOutfitMap.put(fixtureOutfit.name, fixtureOutfit);

        String v3 = downgradeV3(SAONativeSnapshot.capture(person()));
        check(SAONativeSnapshot.validate(v3) && SAONativeSnapshot.formatVersion(v3) == 3,
                "native v3 reader compatibility");
        check(SAONativeSnapshot.restoreStaged(person(), v3) == 0, "native v3 restore compatibility");
        SAONativeSnapshot.unregister(restored);
        SAONativeSnapshot.unregister(restored);
        check(cell.getProcessItemsRemove().size() == 6
                && cell.getProcessItemsRemove().contains(restoredFood)
                && cell.getProcessItemsRemove().contains(restoredRootFood),
                "recursive native processing removal");
        missingPerkRefused(packed, earnedPerk);
        missingPerkRefused(packed, levelPerk);
        missingPerkRefused(packed, multiplierPerk);
        missingPerkRefused(packed, boostPerk);
        missingTraitRefused(packed, customTrait);
        check(!SAONativeSnapshot.validate(packed.substring(0, packed.length() - 4)), "truncation accepted");
        byte[] damaged = Base64.getDecoder().decode(packed.substring(3));
        damaged[30] ^= 1;
        check(!SAONativeSnapshot.validate("v4;" + Base64.getEncoder().encodeToString(damaged)),
                "checksum corruption accepted");
        check(!SAONativeSnapshot.validate(alteredVersion(packed)), "unsupported native version accepted");
        check(!SAONativeSnapshot.validate("v4;%%invalid"), "bad Base64 accepted");
        // Return materials come from the actual turned body. Its absent living
        // components must never replace the supported living-state snapshot.
        SurvivorDesc turnedDesc = new SurvivorDesc();
        turnedDesc.getHumanVisual().setSkinTextureName("returned-appearance");
        var turned = new zombie.characters.IsoZombie(null, turnedDesc, 0);
        turned.setReanimatedPlayer(true);
        check(turned.getBodyDamage() == null && turned.getXp() == null,
                "engine zombie living-component contract changed");
        InventoryContainer detachedBag = (InventoryContainer) bagDefinition.InstanceItem(null, false);
        Food currentFood = (Food) foodDefinition.InstanceItem(null, false);
        currentFood.setAge(9.25f);
        detachedBag.getInventory().AddItem(currentFood);
        turned.getWornItems().setItem(ItemBodyLocation.BACK, detachedBag);
        String returned = SAONativeSnapshot.captureReturn(turned, restored);
        String returnVisual = SAONativeSnapshot.captureReturnVisual(turned);
        IsoPlayer afterCorpse = person();
        SAONativeSnapshot.restoreStaged(afterCorpse, packed);
        // IsoDeadBody transfers the old inventory and clears clothing before
        // SAO's later death observation. Living components remain authoritative.
        afterCorpse.setInventory(new zombie.inventory.ItemContainer());
        afterCorpse.getWornItems().clear();
        afterCorpse.getAttachedItems().clear();
        String livingOnly = SAONativeSnapshot.captureReturnLiving(afterCorpse);
        IsoPlayer retainedLiving = person();
        check(SAONativeSnapshot.restoreStaged(retainedLiving, livingOnly) == 0,
                "living return capture included obsolete possessions");
        check(retainedLiving.getXp().getXP(PerkFactory.Perks.Aiming) == 88.5f
                && retainedLiving.getBodyDamage().getBodyPart(BodyPartType.Hand_R).getHealth() == 63f,
                "post-corpse living components lost");
        check(turned.getInventory().getItems().isEmpty() && detachedBag.getContainer() == null,
                "return capture moved detached equipment");
        IsoPlayer returnee = person();
        check(SAONativeSnapshot.restoreStaged(returnee, returned) == 2,
                "return restored historical possessions");
        Food returnedFood = (Food) ((InventoryContainer) returnee.getWornItem(ItemBodyLocation.BACK))
                .getInventory().getItems().get(0);
        check(returnedFood.id == currentFood.id && returnedFood.getAge() == 9.25f,
                "current nested return item state lost");
        check(!cell.getProcessItems().contains(returnedFood), "detached return item processed before activation");
        check(returnee.getXp().getXP(PerkFactory.Perks.Aiming) == 88.5f
                && returnee.getBodyDamage().getBodyPart(BodyPartType.Hand_R).getHealth() == 63f,
                "return lost supported living components");
        check(SAONativeSnapshot.captureReturnVisual(returnee).equals(returnVisual),
                "return appearance in v4 snapshot did not roundtrip");
        SAONativeSnapshot.restoreReturnVisual(returnee, returnVisual);
        check(SAONativeSnapshot.captureReturnVisual(returnee).equals(returnVisual),
                "return appearance did not roundtrip");
        check(SAONativeSnapshot.returnMaterialsMatch(turned, returned), "unchanged source materials differ");
        currentFood.setAge(10.5f);
        check(!SAONativeSnapshot.returnMaterialsMatch(turned, returned), "changed source materials accepted");
        detachedBag.getInventory().Remove(currentFood);
        check(SAONativeSnapshot.restoreStaged(person(), SAONativeSnapshot.captureReturn(turned, restored)) == 1,
                "looted return item reappeared");
        DICTIONARY.missing((short) 2);
        boolean refused = false;
        try { SAONativeSnapshot.restore(person(), packed); }
        catch (Exception expected) { refused = true; }
        check(refused, "missing nested unequipped script accepted");
        System.out.println("PASS native snapshot: v3/v4; root/nested items and fluids; equipment; "
                + "stats/wounds/XP/traits; nutrition/fitness/learning/visual/ModData; repeated wake; "
                + "dormant partial food/drink and partition stability; next native updates; "
                + "corruption/version/missing-definition controls");
    }
}
