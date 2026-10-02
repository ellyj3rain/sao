import com.sao.engine.SAOAnimalCare;
import com.sao.engine.SAOIsoPlayerShell;
import java.lang.reflect.Field;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.regex.Pattern;
import zombie.characters.CharacterStat;
import zombie.characters.animals.AnimalDefinitions;
import zombie.characters.animals.IsoAnimal;
import zombie.characters.animals.datas.AnimalBreed;
import zombie.characters.animals.datas.AnimalData;
import zombie.inventory.InventoryItem;
import zombie.iso.IsoCell;
import zombie.scripting.ScriptManager;
import zombie.scripting.ScriptParser;
import zombie.scripting.objects.Item;
import zombie.scripting.objects.ScriptModule;
import zombie.world.DictionaryData;
import zombie.world.ItemInfo;
import zombie.world.WorldDictionary;

/** Real native feeding in an isolated cell; no rendering, game launch or save. */
public final class AnimalCareProbe {
    private static int checks;
    private static short nextId = 1800;
    private static IsoCell cell;
    private static Path feeds;
    private static ScriptModule module;
    private static Dictionary dictionary;
    private static java.util.Set<String> extensionFeedTypes;

    private static void check(String name, boolean value) {
        System.out.println("CHECK " + name + "=" + value);
        if (!value) throw new AssertionError(name);
        checks++;
    }
    private static final class Info extends ItemInfo {
        Info(Item item, short id) {
            name = item.getName(); moduleName = "Base"; fullType = "Base." + name;
            registryId = id; isLoaded = true; scriptItem = item; entityScript = item;
            modId = "controlled-native-fixture";
        }
    }
    private static final class Dictionary extends DictionaryData {
        void register(Item item, short id) {
            var info = new Info(item, id);
            itemIdToInfoMap.put(id, info); itemTypeToInfoMap.put(info.getFullType(), info);
        }
    }
    private static Field field(Class<?> type, String name) throws Exception {
        Field result = type.getDeclaredField(name); result.setAccessible(true); return result;
    }
    private static InventoryItem item(String name) throws Exception {
        return item(feeds, name);
    }
    private static InventoryItem item(Path source, String name) throws Exception {
        String text = ScriptParser.stripComments(Files.readString(source));
        var match = Pattern.compile("\\bitem\\s+" + Pattern.quote(name) + "\\s*\\{").matcher(text);
        if (!match.find()) throw new AssertionError("Installed feed missing " + name);
        int end = match.end(), depth = 1;
        while (depth > 0 && end < text.length()) {
            char c = text.charAt(end++); if (c == '{') depth++; else if (c == '}') depth--;
        }
        Item definition = module.items.getScriptMap().get(name);
        if (definition == null) {
            definition = new Item(); definition.setModule(module); definition.setName(name);
            String ownedDefinition = text.substring(match.start(), end);
            // The isolated legacy Item.Load fixture has no recipe research registry.
            // Remove only the unrelated empty-bucket research row; feeds remain exact installed bytes.
            if (name.equals("Bucket") && source.getFileName().toString().equals("normal.txt"))
                ownedDefinition = ownedDefinition.replaceAll("(?m)^\\s*Researchablerecipes\\s*=.*$", "");
            definition.Load(name, ownedDefinition);
            definition.setRegistry_id(nextId++);
            module.items.getScriptMap().put(name, definition); dictionary.register(definition, definition.getRegistry_id());
        }
        InventoryItem value = definition.InstanceItem(null);
        value.setID(nextId++); value.setName(name);
        return value;
    }
    private static SAOIsoPlayerShell body(String id) throws Exception {
        var create = MovementCrossingProbe.class.getDeclaredMethod("person", IsoCell.class);
        create.setAccessible(true); var body = (SAOIsoPlayerShell) create.invoke(null, cell);
        body.playerIndex = 99; body.getModData().rawset("SAOPersonId", id);
        body.setSquare(body.getCurrentSquare()); body.getSquare().getMovingObjects().add(body);
        cell.getObjectList().add(body);
        return body;
    }
    private static IsoAnimal animal() throws Exception {
        var animal = new IsoAnimal(cell);
        animal.adef = new AnimalDefinitions();
        animal.adef.canBeFeedByHand = true;
        animal.adef.feedByHandAnim = "AnimalLureLow";
        animal.adef.hungerBoost = 1;
        animal.adef.eatTypeTrough = new ArrayList<>();
        animal.adef.feedByHandType = new ArrayList<>();
        var breed = new AnimalBreed(); breed.milkType = "CowMilk";
        animal.setData(new AnimalData(animal, breed));
        animal.getData().currentStage = new zombie.characters.animals.datas.AnimalGrowStage();
        animal.getData().currentStage.nextStage = "adult-fixture";
        field(IsoAnimal.class, "behavior").set(animal, new zombie.characters.animals.behavior.BaseAnimalBehavior(animal));
        animal.setX(11.5f); animal.setY(20.5f); animal.setZ(0);
        animal.setCurrent(cell.getGridSquare(11, 20, 0));
        animal.setSquare(animal.getCurrentSquare()); animal.getSquare().getMovingObjects().add(animal);
        animal.setAnimalID(nextId++);
        cell.getObjectList().add(animal);
        animal.getStats().set(CharacterStat.HUNGER, 0.4f);
        return animal;
    }
    private static InventoryItem carried(SAOIsoPlayerShell body, IsoAnimal animal) throws Exception {
        InventoryItem food = item("FeedForPiglet"); body.getInventory().AddItem(food);
        if (extensionFeedTypes.contains(food.getAnimalFeedType())) animal.adef.eatTypeTrough.add(food.getAnimalFeedType());
        animal.getStats().set(CharacterStat.HUNGER, .4f);
        return food;
    }
    private static String capture(SAOIsoPlayerShell body, IsoAnimal animal, InventoryItem food) {
        String token = SAOAnimalCare.beginFeed(body, animal, food);
        if (token.isEmpty() || token.equals("BUSY")) throw new AssertionError("CONTROL_CAPTURE_NOT_VALID");
        return token;
    }
    private static void integrated(Path prelude, Path source, Path cases) throws Exception {
        var nativeBody = body("care-native"); var nativeAnimal = animal(); var nativeFood = carried(nativeBody, nativeAnimal);
        var platform = new se.krka.kahlua.j2se.J2SEPlatform(); var env = platform.newEnvironment();
        var thread = new se.krka.kahlua.vm.KahluaThread(platform, env); thread.debugOwnerThread = Thread.currentThread();
        zombie.Lua.LuaManager.platform = platform; zombie.Lua.LuaManager.env = env; zombie.Lua.LuaManager.thread = thread;
        zombie.ui.UIManager.defaultthread = thread;
        var converters = new se.krka.kahlua.converter.KahluaConverterManager();
        zombie.Lua.KahluaNumberConverter.install(converters);
        zombie.Lua.LuaManager.converterManager = converters;
        zombie.Lua.LuaManager.caller = new se.krka.kahlua.integration.LuaCaller(converters);
        var exposer = new zombie.Lua.LuaManager.Exposer(converters, platform, env);
        for (Class<?> type : new Class<?>[]{SAOIsoPlayerShell.class, zombie.characters.IsoPlayer.class,
            zombie.characters.IsoGameCharacter.class, zombie.iso.IsoMovingObject.class, IsoAnimal.class,
            InventoryItem.class, zombie.inventory.types.DrainableComboItem.class, zombie.inventory.types.Food.class,
            zombie.inventory.ItemContainer.class, zombie.entity.components.fluids.FluidContainer.class,
            zombie.characters.animals.behavior.BaseAnimalBehavior.class, zombie.characters.CharacterSoundEmitter.class,
            zombie.audio.BaseSoundEmitter.class, zombie.iso.IsoGridSquare.class}) {
            exposer.setExposed(type); exposer.exposeLikeJava(type, env);
        }
        var bridge = platform.newTable(); env.rawset("SAOJavaBridge", bridge);
        bridge.rawset("isShell", (se.krka.kahlua.vm.JavaFunction) (frame, count) -> {
            frame.push(frame.get(1) instanceof SAOIsoPlayerShell); return 1;
        });
        bridge.rawset("animalCareBeginFeed", (se.krka.kahlua.vm.JavaFunction) (frame, count) -> {
            frame.push(SAOAnimalCare.beginFeed(frame.get(1), frame.get(2), frame.get(3))); return 1;
        });
        bridge.rawset("animalCarePrepareFeed", (se.krka.kahlua.vm.JavaFunction) (frame, count) -> {
            frame.push(SAOAnimalCare.prepareFeed(frame.get(1), (String) frame.get(2), frame.get(3), frame.get(4))); return 1;
        });
        bridge.rawset("animalCareFinishFeed", (se.krka.kahlua.vm.JavaFunction) (frame, count) -> {
            frame.push(SAOAnimalCare.finishFeed(frame.get(1), (String) frame.get(2), frame.get(3), frame.get(4), Boolean.TRUE.equals(frame.get(5)))); return 1;
        });
        bridge.rawset("animalCareCancelFeed", (se.krka.kahlua.vm.JavaFunction) (frame, count) -> {
            SAOAnimalCare.cancelFeed(frame.get(1), (String) frame.get(2)); return 0;
        });
        env.rawset("__nativeBody", nativeBody); env.rawset("__nativeAnimal", nativeAnimal); env.rawset("__nativeFood", nativeFood);
        Path game = Path.of(IsoAnimal.class.getProtectionDomain().getCodeSource().getLocation().toURI()).getParent();
        for (Path path : java.util.List.of(prelude, game.resolve("media/lua/shared/ISBaseObject.lua"),
                game.resolve("media/lua/shared/TimedActions/ISBaseTimedAction.lua"),
                game.resolve("media/lua/shared/TimedActions/Animals/ISFeedAnimalFromHand.lua"), source, cases))
            thread.call(se.krka.kahlua.luaj.compiler.LuaCompiler.loadstring(Files.readString(path), path.toString(), env), null, null, null);
        check("installed_action_native_receiver_and_owned_wrapper_join", Boolean.TRUE.equals(env.rawget("__nativeCareIntegrated")));
        check("integrated_exact_feed_really_consumed", nativeFood.getCurrentUses() == 0 && nativeAnimal.getHunger() < .4f);
        check("integrated_capture_released", SAOAnimalCare.pendingCount() == 0);
    }
    public static void main(String[] args) throws Exception {
        if (args.length != 2 && args.length != 5) throw new IllegalArgumentException("installed feed script/extension, optional integrated prelude/owner/cases");
        feeds = Path.of(args[0]);
        var boot = MovementCrossingProbe.class.getDeclaredMethod("boot"); boot.setAccessible(true);
        cell = (IsoCell) boot.invoke(null);
        module = new ScriptModule(); module.name = "Base";
        ScriptManager.instance.moduleMap.put("Base", module);
        ((zombie.scripting.ScriptBucketCollection<?>) field(ScriptManager.class, "items").get(ScriptManager.instance)).registerModule(module);
        dictionary = new Dictionary(); field(WorldDictionary.class, "data").set(null, dictionary);
        Path game = Path.of(IsoAnimal.class.getProtectionDomain().getCodeSource().getLocation().toURI()).getParent();
        item(game.resolve("media/scripts/generated/items/normal.txt"), "Bowl");
        AnimalDefinitions.animalDefs = new java.util.HashMap<>();
        var platform = new se.krka.kahlua.j2se.J2SEPlatform();
        var env = platform.newEnvironment();
        var thread = new se.krka.kahlua.vm.KahluaThread(platform, env); thread.debugOwnerThread = Thread.currentThread();
        thread.call(se.krka.kahlua.luaj.compiler.LuaCompiler.loadstring(
            "AnimalDefinitions={animals={piglet={},rabkitten={},cowcalf={},lamb={}}}", "fixture-native-species", env), null, null, null);
        thread.call(se.krka.kahlua.luaj.compiler.LuaCompiler.loadstring(Files.readString(Path.of(args[1])), "actual-shared-feed-extension", env), null, null, null);
        var definitions = (se.krka.kahlua.vm.KahluaTable) ((se.krka.kahlua.vm.KahluaTable) env.rawget("AnimalDefinitions")).rawget("animals");
        extensionFeedTypes = new java.util.HashSet<>();
        for (String species : java.util.List.of("piglet", "rabkitten", "cowcalf", "lamb")) {
            Object type = ((se.krka.kahlua.vm.KahluaTable) definitions.rawget(species)).rawget("eatTypeTrough");
            check("actual_shared_extension_" + species, type instanceof String && !((String) type).isEmpty());
            extensionFeedTypes.add((String) type);
        }
        var body = body("care-a"); var animal = animal(); var food = carried(body, animal);
        check("real_native_body_and_animal_exist", body.isExistInTheWorld() && animal.isExistInTheWorld());
        animal.adef.eatTypeTrough.clear();
        check("unknown_extension_feed_refuses", SAOAnimalCare.beginFeed(body, animal, food).isEmpty());
        animal.adef.eatTypeTrough.add(food.getAnimalFeedType());
        check("definition_extension_enters_native_whitelist", animal.getEatTypePossibleFromHand().contains(food.getAnimalFeedType())
            && animal.getPossibleLuringItems(body).contains(food));
        String token = capture(body, animal, food);
        check("accepted_exact_feed_captures_without_effect", !token.isEmpty() && !token.equals("BUSY")
            && food.getCurrentUses() == 1 && animal.getHunger() == 0.4f);
        check("pending_capture_is_bounded_one_per_body", SAOAnimalCare.beginFeed(body, animal, food).equals("BUSY"));
        check("native_completion_prepares", SAOAnimalCare.prepareFeed(body, token, animal, food));
        float before = animal.getHunger(); animal.feedFromHand(body, food);
        String result = SAOAnimalCare.finishFeed(body, token, animal, food, true);
        check("actual_native_consumption_and_need_change_complete", result.startsWith("completed@")
            && food.getCurrentUses() == 0 && animal.getHunger() < before && result.contains("@uses@1.0@0.0@"));
        check("native_receipt_is_once", SAOAnimalCare.finishFeed(body, token, animal, food, true).isEmpty());
        check("completed_capture_releases_slot", SAOAnimalCare.pendingCount() == 0);

        food = carried(body, animal); animal.getStats().set(CharacterStat.HUNGER, .4f);
        token = capture(body, animal, food); SAOAnimalCare.prepareFeed(body, token, animal, food);
        animal.getStats().set(CharacterStat.HUNGER, .3f);
        check("hunger_change_without_exact_consumption_refuses_success", SAOAnimalCare.finishFeed(body, token, animal, food, true).startsWith("no-effect@"));
        token = capture(body, animal, food); SAOAnimalCare.prepareFeed(body, token, animal, food);
        food.Use();
        check("consumption_without_need_change_refuses_success", SAOAnimalCare.finishFeed(body, token, animal, food, true).startsWith("no-effect@"));

        food = carried(body, animal); token = capture(body, animal, food);
        animal.getStats().set(CharacterStat.HUNGER, .2f); // An earlier event cannot count as this action's effect.
        check("precompletion_baseline_refreshes", SAOAnimalCare.prepareFeed(body, token, animal, food));
        food.Use();
        check("earlier_need_change_does_not_complete", SAOAnimalCare.finishFeed(body, token, animal, food, true).startsWith("no-effect@"));
        food = carried(body, animal);
        token = capture(body, animal, food); SAOAnimalCare.prepareFeed(body, token, animal, food);
        before = animal.getHunger(); animal.feedFromHand(body, food);
        check("interrupted_partial_effect_cannot_be_success", SAOAnimalCare.finishFeed(body, token, animal, food, false).startsWith("interrupted@"));
        check("instrument_does_not_roll_back_native_effect", animal.getHunger() < before);

        food = carried(body, animal); token = capture(body, animal, food);
        InventoryItem other = carried(body, animal); other.setID(food.getID());
        check("same_id_replacement_item_refuses", !SAOAnimalCare.prepareFeed(body, token, animal, other));
        token = capture(body, animal, food);
        var otherAnimal = animal(); otherAnimal.setAnimalID(animal.getAnimalID());
        check("same_id_replacement_animal_refuses", !SAOAnimalCare.prepareFeed(body, token, otherAnimal, food));
        token = capture(body, animal, food); body.getModData().rawset("SAOPersonId", "care-b");
        check("person_rebinding_refuses", !SAOAnimalCare.prepareFeed(body, token, animal, food));
        body.getModData().rawset("SAOPersonId", "care-a");
        token = capture(body, animal, food); body.removalPending = true;
        check("pending_body_removal_refuses", !SAOAnimalCare.prepareFeed(body, token, animal, food)); body.removalPending = false;
        token = capture(body, animal, food); SAOAnimalCare.forget(body);
        check("forgotten_body_cannot_complete", SAOAnimalCare.finishFeed(body, token, animal, food, true).isEmpty());
        token = capture(body, animal, food); SAOAnimalCare.resetRuntimeForWorld();
        check("world_reset_invalidates_existing_token", !SAOAnimalCare.prepareFeed(body, token, animal, food));
        check("wrong_java_types_refuse", SAOAnimalCare.beginFeed("fake", animal, food).isEmpty()
            && !SAOAnimalCare.prepareFeed(body, "fake", "animal", food));
        animal.adef.eatTypeTrough.clear();
        check("changed_native_feed_membership_refuses", SAOAnimalCare.beginFeed(body, animal, food).isEmpty());
        animal.adef.eatTypeTrough.add(food.getAnimalFeedType());
        animal.setX(15.5f); animal.setCurrent(cell.getGridSquare(15, 20, 0));
        check("distant_animal_is_not_interaction", SAOAnimalCare.beginFeed(body, animal, food).isEmpty());
        animal.setX(11.5f); animal.setCurrent(cell.getGridSquare(11, 20, 0));
        var square = cell.getGridSquare(11, 20, 0); square.getProperties().set(zombie.iso.SpriteDetails.IsoFlagType.collideW);
        check("wall_blocks_native_care", SAOAnimalCare.beginFeed(body, animal, food).isEmpty());
        square.getProperties().unset(zombie.iso.SpriteDetails.IsoFlagType.collideW);
        for (String name : java.util.List.of("FeedForPiglet", "FeedForPigletInClayBowl", "FeedForRabkitten",
                "FeedForRabkittenInClayBowl", "FeedForCowcalf", "FeedForLamb")) {
            if (name.contains("ClayBowl")) item(game.resolve("media/scripts/generated/items/normal.txt"), "ClayBowl");
            if (name.contains("Cowcalf") || name.contains("Lamb")) item(game.resolve("media/scripts/generated/items/normal.txt"), "Bucket");
            var target = animal(); var feed = item(name); body.getInventory().AddItem(feed);
            check("actual_feed_type_declared_" + name, extensionFeedTypes.contains(feed.getAnimalFeedType()));
            target.adef.eatTypeTrough.add(feed.getAnimalFeedType());
            String key = SAOAnimalCare.beginFeed(body, target, feed);
            check("actual_feed_prepares_" + name, !key.isEmpty() && SAOAnimalCare.prepareFeed(body, key, target, feed));
            target.feedFromHand(body, feed);
            check("actual_native_feed_completes_" + name, SAOAnimalCare.finishFeed(body, key, target, feed, true).startsWith("completed@"));
        }
        var retained = new java.util.ArrayList<SAOIsoPlayerShell>();
        for (int index = 0; index < 128; index++) {
            var participant = body("care-capacity-" + index); retained.add(participant);
            var target = animal(); var feed = carried(participant, target);
            if (SAOAnimalCare.beginFeed(participant, target, feed).isEmpty()) throw new AssertionError("capacity fixture refused valid input");
        }
        check("native_pending_capacity_is_128", SAOAnimalCare.pendingCount() == 128);
        var extra = body("care-capacity-extra"); var extraAnimal = animal(); var extraFood = carried(extra, extraAnimal);
        check("native_capacity_saturation_is_explicit_busy", SAOAnimalCare.beginFeed(extra, extraAnimal, extraFood).equals("BUSY"));
        extraAnimal.feedFromHand(extra, extraFood);
        check("saturation_does_not_change_native_feed_owner", extraFood.getCurrentUses() == 0 && extraAnimal.getHunger() < .4f);
        SAOAnimalCare.resetRuntimeForWorld();
        check("capacity_reset_releases_all_slots", SAOAnimalCare.pendingCount() == 0);
        if (args.length == 5) integrated(Path.of(args[2]), Path.of(args[3]), Path.of(args[4]));
        System.out.println("ANIMAL_CARE_NATIVE_OK " + checks);
    }
}
