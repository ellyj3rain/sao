import com.sao.engine.SAOPrivateInventory;
import zombie.characters.IsoPlayer;
import zombie.characters.SurvivorDesc;
import zombie.inventory.InventoryItem;
import zombie.inventory.types.InventoryContainer;
import zombie.inventory.types.Radio;
import zombie.radio.devices.DeviceData;
import zombie.scripting.ScriptManager;
import zombie.scripting.objects.Item;
import zombie.scripting.objects.ItemType;
import zombie.scripting.objects.ScriptModule;
import zombie.world.DictionaryData;
import zombie.world.ItemInfo;
import zombie.world.WorldDictionary;

/** Installed Build 42.20 proof for C73 radio endpoint state. */
public final class RadioReceptionProbe {
    private static int nextId = 7300;
    private static final FixtureDictionary DICTIONARY = new FixtureDictionary();

    private static final class FixtureInfo extends ItemInfo {
        FixtureInfo(Item definition, short id) {
            name = definition.getName();
            moduleName = "C73";
            fullType = "C73." + name;
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
        final Item definition = new Item();
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
        hair.name = "C73Hair";
        hair.model = "C73HairModel";
        hair.texture = "C73HairTexture";
        zombie.core.skinnedmodel.population.HairStyles.instance.maleStyles.add(hair);
        zombie.core.skinnedmodel.population.HairStyles.instance.femaleStyles.add(hair);
        var beard = new zombie.core.skinnedmodel.population.BeardStyle();
        beard.name = "C73Beard";
        beard.model = "C73BeardModel";
        beard.texture = "C73BeardTexture";
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

    private static Radio radio(FixtureItem fixture) {
        Radio radio = (Radio) fixture.create();
        DeviceData data = radio.getDeviceData();
        check(data != null, "device_data");
        data.setChannelRaw(101200);
        data.setDeviceVolumeRaw(0.8f);
        data.setIsBatteryPowered(true);
        data.setHasBattery(true);
        data.setPower(0.6f);
        data.setUseDelta(0.3f);
        data.setIsTwoWay(true);
        data.setMicIsMuted(false);
        data.setNoTransmit(false);
        data.setTurnedOnRaw(true);
        return radio;
    }

    private static float accessPower(String access) {
        int split = access.lastIndexOf(':');
        return Float.parseFloat(access.substring(split + 1));
    }

    public static void main(String[] args) throws Exception {
        boot();
        ScriptModule module = new ScriptModule();
        module.name = "C73";
        ScriptManager.instance.moduleMap.put("C73", module);
        FixtureItem receiverDefinition = new FixtureItem(module, "Receiver",
            ItemType.RADIO, (short) 73);
        receiverDefinition.definition.displayCategory = "Communications";
        receiverDefinition.definition.isTelevision = false;
        FixtureItem televisionDefinition = new FixtureItem(module, "Television",
            ItemType.RADIO, (short) 74);
        televisionDefinition.definition.displayCategory = "Communications";
        televisionDefinition.definition.isTelevision = true;
        FixtureItem bagDefinition = new FixtureItem(module, "Bag",
            ItemType.CONTAINER, (short) 75);

        IsoPlayer source = person("radio-source");
        Radio receiver = radio(receiverDefinition);
        DeviceData data = receiver.getDeviceData();
        source.getInventory().AddItem(receiver);
        check(SAOPrivateInventory.loadedRadioAccess(source, 101200, false)
                .startsWith("AVAILABLE:"), "receiver_available");
        check(SAOPrivateInventory.loadedRadioAccess(source, 101200, true)
                .startsWith("AVAILABLE:"), "transmitter_available");

        String captured = SAOPrivateInventory.captureRadioState(source);
        check(SAOPrivateInventory.validateRadioState(captured), "state_valid");
        data.setTurnedOnRaw(false);
        check(SAOPrivateInventory.loadedRadioAccess(source, 101200, false)
                .equals("REFUSED:off"), "off_refused");
        data.setTurnedOnRaw(true);
        data.setChannelRaw(99200);
        check(SAOPrivateInventory.loadedRadioAccess(source, 101200, false)
                .equals("REFUSED:mistuned"), "mistuned_refused");
        data.setChannelRaw(101200);
        data.setDeviceVolumeRaw(0.0f);
        check(SAOPrivateInventory.loadedRadioAccess(source, 101200, false)
                .equals("REFUSED:silent"), "silent_refused");
        data.setDeviceVolumeRaw(0.8f);
        data.setPower(0.0f);
        check(SAOPrivateInventory.loadedRadioAccess(source, 101200, false)
                .equals("REFUSED:unpowered"), "unpowered_refused");
        data.setPower(0.6f);
        data.setMicIsMuted(true);
        check(SAOPrivateInventory.loadedRadioAccess(source, 101200, true)
                .equals("REFUSED:muted"), "muted_refused");
        data.setMicIsMuted(false);
        data.setIsTwoWay(false);
        check(SAOPrivateInventory.loadedRadioAccess(source, 101200, false)
                .startsWith("AVAILABLE:")
                && SAOPrivateInventory.loadedRadioAccess(source, 101200, true)
                    .equals("REFUSED:receive-only"), "two_way_directed");
        data.setIsTwoWay(true);

        InventoryContainer bag = (InventoryContainer) bagDefinition.create();
        source.getInventory().Remove(receiver);
        bag.getInventory().AddItem(receiver);
        source.getInventory().AddItem(bag);
        check(SAOPrivateInventory.loadedRadioAccess(source, 101200, false)
                .equals("REFUSED:no-direct-receiver"), "nested_refused");
        String nested = SAOPrivateInventory.captureRadioState(source);
        check(SAOPrivateInventory.dormantRadioAccess(nested, 101200, false)
                .equals("REFUSED:no-direct-receiver"), "nested_not_checkpointed");

        Radio television = radio(televisionDefinition);
        source.getInventory().AddItem(television);
        check(!SAOPrivateInventory.isRadioReceiver(television), "television_excluded");

        float rate = data.getUseDelta();
        check(rate > 0.0f, "use_rate");
        String advanced = SAOPrivateInventory.advanceRadioState(captured, 0.5);
        String access = SAOPrivateInventory.dormantRadioAccess(
            advanced, 101200, false);
        float expected = Math.max(0.0f, 0.6f - rate * 30.0f);
        check(access.startsWith("AVAILABLE:")
                && Math.abs(accessPower(access) - expected) < 0.0001f,
            "elapsed_power");

        IsoPlayer restored = person("radio-restored");
        Radio restoredRadio = radio(receiverDefinition);
        restoredRadio.id = receiver.id;
        restored.getInventory().AddItem(restoredRadio);
        check(SAOPrivateInventory.applyRadioState(restored, advanced)
                && Math.abs(restoredRadio.getDeviceData().getPower() - expected)
                    < 0.0001f
                && restoredRadio.getDeviceData().getIsTurnedOn(),
            "wake_overlay");

        double depletionHours = 0.6 / (rate * 60.0) + 1.0;
        String depleted = SAOPrivateInventory.advanceRadioState(
            captured, depletionHours);
        check(SAOPrivateInventory.dormantRadioAccess(depleted, 101200, false)
                .equals("REFUSED:off"), "depletion_refused");
        IsoPlayer exhausted = person("radio-exhausted");
        Radio exhaustedRadio = radio(receiverDefinition);
        exhaustedRadio.id = receiver.id;
        exhausted.getInventory().AddItem(exhaustedRadio);
        check(SAOPrivateInventory.applyRadioState(exhausted, depleted)
                && exhaustedRadio.getDeviceData().getPower() == 0.0f
                && !exhaustedRadio.getDeviceData().getIsTurnedOn(),
            "depletion_overlay");

        restoredRadio.getDeviceData().setChannelRaw(99200);
        check(!SAOPrivateInventory.applyRadioState(restored, advanced),
            "mismatched_restore_refused");

        IsoPlayer pairSource = person("radio-pair-source");
        Radio pairFirst = radio(receiverDefinition);
        Radio pairSecond = radio(receiverDefinition);
        pairSource.getInventory().AddItem(pairFirst);
        pairSource.getInventory().AddItem(pairSecond);
        String pairState = SAOPrivateInventory.captureRadioState(pairSource);
        IsoPlayer pairTarget = person("radio-pair-target");
        Radio targetFirst = radio(receiverDefinition);
        Radio targetSecond = radio(receiverDefinition);
        targetFirst.id = pairFirst.id;
        targetSecond.id = pairSecond.id;
        targetFirst.getDeviceData().setPower(0.95f);
        targetSecond.getDeviceData().setChannelRaw(99200);
        pairTarget.getInventory().AddItem(targetFirst);
        pairTarget.getInventory().AddItem(targetSecond);
        check(!SAOPrivateInventory.applyRadioState(pairTarget, pairState)
                && Math.abs(targetFirst.getDeviceData().getPower() - 0.95f)
                    < 0.0001f,
            "transactional_restore");
        check(!SAOPrivateInventory.validateRadioState("SAORAD1;broken"),
            "malformed_refused");
        System.out.println("PASS radio state: direct receiver/transmitter; "
            + "off/tuning/volume/power; nested and television refusal; "
            + "elapsed battery and wake overlay");
    }
}
