import com.sao.engine.SAOCooking;
import com.sao.engine.SAOIsoPlayerShell;
import java.nio.file.Path;
import se.krka.kahlua.j2se.J2SEPlatform;
import se.krka.kahlua.vm.KahluaThread;
import zombie.Lua.LuaManager;
import zombie.characters.IsoPlayer;
import zombie.characters.skills.PerkFactory;
import zombie.inventory.ItemContainer;
import zombie.inventory.types.Food;
import zombie.iso.IsoCell;
import zombie.iso.objects.IsoStove;
import zombie.iso.sprite.IsoSprite;
import zombie.scripting.ScriptManager;
import zombie.world.WorldDictionary;

/** Controlled installed-engine bodies, appliance, item definitions and Food.update. */
public final class CookingProbe {
    private static void position(SAOIsoPlayerShell body, IsoCell cell, float x, float y) {
        if (body.getCurrentSquare() != null) body.getCurrentSquare().getMovingObjects().remove(body);
        body.setX(x); body.setY(y); body.setZ(0);
        body.setCurrent(cell.getGridSquare((int) x, (int) y, 0)); body.setSquare(body.getCurrentSquare());
        body.getCurrentSquare().getMovingObjects().add(body);
    }
    static void check(String name, boolean result) {
        System.out.println("CHECK " + name + "=" + result);
        if (!result) throw new AssertionError(name);
    }
    public static void main(String[] args) throws Exception {
        var boot = MovementCrossingProbe.class.getDeclaredMethod("boot"); boot.setAccessible(true);
        var cell = (IsoCell) boot.invoke(null);
        var create = MovementCrossingProbe.class.getDeclaredMethod("person", IsoCell.class); create.setAccessible(true);
        var body = (SAOIsoPlayerShell) create.invoke(null, cell); body.playerIndex = 99;
        cell.getObjectList().add(body);
        body.setSquare(body.getCurrentSquare());
        if (!body.getCurrentSquare().getMovingObjects().contains(body))
            body.getCurrentSquare().getMovingObjects().add(body);
        body.getModData().rawset("SAOPersonId", "cook-1");
        for (int i = 0; i < IsoPlayer.players.length; i++) IsoPlayer.players[i] = null;
        LuaManager.platform = new J2SEPlatform(); LuaManager.env = LuaManager.platform.newEnvironment();
        LuaManager.thread = new KahluaThread(LuaManager.platform, LuaManager.env);
        LuaManager.thread.debugOwnerThread = Thread.currentThread();
        zombie.ui.UIManager.defaultthread = LuaManager.thread;
        zombie.Lua.LuaEventManager.register(LuaManager.platform, LuaManager.env);
        var init = ResourceApproachProbe.class.getDeclaredMethod("initFluids"); init.setAccessible(true); init.invoke(null);
        var dictionaryClass = Class.forName("CognitionUseProbe$Dictionary");
        var constructor = dictionaryClass.getDeclaredConstructor(); constructor.setAccessible(true);
        var dictionary = constructor.newInstance();
        var data = WorldDictionary.class.getDeclaredField("data"); data.setAccessible(true); data.set(null, dictionary);
        var module = ScriptManager.instance.getModule("Base");
        var itemMethod = CognitionUseProbe.class.getDeclaredMethod("item", Path.class,
            zombie.scripting.objects.ScriptModule.class, dictionaryClass, String.class, String.class, short.class);
        itemMethod.setAccessible(true);
        var food = (Food) itemMethod.invoke(null, Path.of(args[0]), module, dictionary, "food.txt", "MuttonChop", (short) 2801);
        food.setChef("Original Cook"); body.getInventory().AddItem(food);
        var square = cell.getGridSquare(10, 20, 0);
        var stove = new IsoStove(cell, square, new IsoSprite());
        var container = new ItemContainer("stove", square, stove);
        stove.setContainer(container); square.getObjects().add(stove);
        square.chunk.addGeneratorPos(10, 20, 0);
        check("native_appliance_exact_and_reachable", SAOCooking.inspect(body, stove, container) != null);
        check("native_power_observed", container.isPowered());
        boolean offered = false;
        try {
            var offers = SAOCooking.offers(body, 2);
            var appliances = (se.krka.kahlua.vm.KahluaTable) offers.rawget("appliances");
            var row = (se.krka.kahlua.vm.KahluaTable) appliances.rawget(1.0);
            offered = row != null && row.rawget("object") == stove
                && row.rawget("container") == container;
        } catch (RuntimeException error) {
            System.out.println("OFFER_FAILURE " + error);
        }
        check("native_object_collection_offers_appliance", offered);
        check("missing_container_refused", !SAOCooking.beginHeat(body, "cook/1", food, stove, null));
        check("carried_food_cannot_bind_heat", !SAOCooking.beginHeat(body, "cook/1", food, stove, container));
        body.getInventory().DoRemoveItem(food); container.AddItem(food);
        IsoPlayer.players[0] = body;
        check("registered_player_refused", !SAOCooking.beginHeat(body, "cook/1", food, stove, container));
        IsoPlayer.players[0] = null;
        body.setAsleep(true);
        check("sleeping_body_refused", !SAOCooking.beginHeat(body, "cook/1", food, stove, container));
        body.setAsleep(false);
        check("physical_deposit_binds_raw_item", SAOCooking.beginHeat(body, "cook/1", food, stove, container));
        check("same_binding_idempotent", SAOCooking.beginHeat(body, "cook/1", food, stove, container)
            && !SAOCooking.beginHeat(body, "cook/other", food, stove, container));
        // Native05's exact geometry, translated to this real loaded fixture.
        position(body, cell, 12.24072265625f, 21.4765625f);
        check("recorded_cook_position_is_barely_in_reach", SAOCooking.inspect(body, stove, container) != null);
        position(body, cell, 12.30f, 21.50f);
        Object originalBinding = food.getModData().rawget("SAOCookingBinding");
        float displacedXp = body.getXp().getXP(PerkFactory.Perks.Cooking);
        check("small_displacement_requires_physical_return", SAOCooking.inspect(body, stove, container) == null
            && SAOCooking.heatState(body, "cook/1") == null && SAOCooking.completeHeat(body, "cook/1") == null);
        var approach = SAOCooking.approach(body, stove, container);
        check("reapproach_has_same_source_and_fresh_coordinates", approach != null
            && Double.valueOf(10).equals(approach.rawget("sourceX"))
            && Double.valueOf(20).equals(approach.rawget("sourceY"))
            && approach.rawget("temperature") == null && approach.rawget("item") == null);
        int ax = ((Number) approach.rawget("approachX")).intValue();
        int ay = ((Number) approach.rawget("approachY")).intValue();
        var target = cell.getGridSquare(ax, ay, 0);
        check("fresh_approach_center_is_standable_and_within_strict_reach",
            target != null && target.isFree(false) && !target.isSomethingTo(square)
                && (ax - 10) * (ax - 10) + (ay - 20) * (ay - 20) <= 2);
        check("approach_does_not_advance_heat_or_credit", originalBinding.equals(food.getModData().rawget("SAOCookingBinding"))
            && food.getCookingTime() == 0 && !food.isCooked() && !stove.Activated()
            && body.getXp().getXP(PerkFactory.Perks.Cooking) == displacedXp);
        square.getObjects().remove(stove);
        check("removed_appliance_cannot_supply_reapproach", SAOCooking.approach(body, stove, container) == null);
        square.getObjects().add(stove);
        var replacedContainer = new ItemContainer("stove", square, stove);
        check("unregistered_container_cannot_supply_reapproach", SAOCooking.approach(body, stove, replacedContainer) == null);
        position(body, cell, 29.5f, 20.5f);
        check("reapproach_is_locally_bounded", SAOCooking.approach(body, stove, container) == null);
        position(body, cell, ax + 0.5f, ay + 0.5f);
        check("physical_return_restores_original_heat_binding", SAOCooking.inspect(body, stove, container) != null
            && SAOCooking.heatState(body, "cook/1") != null
            && originalBinding.equals(food.getModData().rawget("SAOCookingBinding")));
        position(body, cell, 10.5f, 20.5f);
        check("offslot_chef_lookup_suppressed", food.getChef() == null);
        var other = (SAOIsoPlayerShell) create.invoke(null, cell); other.playerIndex = 98;
        other.setSquare(other.getCurrentSquare()); other.getCurrentSquare().getMovingObjects().add(other);
        cell.getObjectList().add(other); other.getModData().rawset("SAOPersonId", "cook-2");
        check("one_body_owns_exact_item", !SAOCooking.beginHeat(other, "cook/other", food, stove, container));
        other.getDescriptor().setForename("Original"); other.getDescriptor().setSurname("Cook");
        IsoPlayer.players[0] = other;
        float otherXp = other.getXp().getXP(PerkFactory.Perks.Cooking);
        body.getModData().rawset("SAOExternalToken", "changed");
        check("changed_owner_token_refused", SAOCooking.heatState(body, "cook/1") == null);
        body.getModData().rawset("SAOExternalToken", null);
        body.getModData().rawset("SAOPersonId", "other-identity");
        check("changed_actor_identity_refused", SAOCooking.heatState(body, "cook/1") == null);
        body.getModData().rawset("SAOPersonId", "cook-1");
        body.getSquare().getMovingObjects().remove(body);
        check("detached_body_refused", SAOCooking.heatState(body, "cook/1") == null);
        body.getSquare().getMovingObjects().add(body);
        square.getObjects().remove(stove);
        check("removed_appliance_refused", SAOCooking.heatState(body, "cook/1") == null);
        square.getObjects().add(stove);
        food.setChef("Different Cook");
        check("intervening_chef_change_refused", SAOCooking.heatState(body, "cook/1") == null);
        food.setChef(null);
        float beforeXp = body.getXp().getXP(PerkFactory.Perks.Cooking);
        var initial = SAOCooking.heatState(body, "cook/1");
        check("queued_work_not_cooked_or_credited", !food.isCooked()
            && Boolean.FALSE.equals(initial.rawget("progressed"))
            && SAOCooking.completeHeat(body, "cook/1") == null);
        // Restored historic shortcut: cooked flag alone is not a thermal result.
        food.cooked = true;
        check("fake_cooked_field_rejected", SAOCooking.completeHeat(body, "cook/1") == null
            && body.getXp().getXP(PerkFactory.Perks.Cooking) == beforeXp);
        food.cooked = false;
        food.setCooked(true);
        check("fake_cooked_write_rejected", SAOCooking.completeHeat(body, "cook/1") == null
            && body.getXp().getXP(PerkFactory.Perks.Cooking) == beforeXp);
        food.setCooked(false); food.setCookingTime(0);
        for (int minute = 1; minute <= 10; minute++) {
            zombie.GameTime.getInstance().setTimeOfDay(12 + minute / 60.0f); food.update();
        }
        check("cold_appliance_has_no_thermal_progress", !food.isCooked() && food.getCookingTime() == 0);
        stove.setMaxTemperature(200); stove.setActivated(true);
        float first = stove.getCurrentTemperature();
        for (int i = 0; i < 8000; i++) stove.update();
        check("native_stove_update_warms_container", stove.Activated()
            && stove.getCurrentTemperature() > first && container.getTemprature() > 1.6f);
        for (int frame = 0; frame < 2000; frame++) food.update();
        float paused = food.getCookingTime();
        for (int frame = 0; frame < 2000; frame++) food.update();
        check("same_native_minute_cannot_fast_forward_cooking", food.getCookingTime() == paused && !food.isCooked());
        int minute = 11;
        for (; minute < 350 && !food.isCooked(); minute++) {
            zombie.GameTime.getInstance().setTimeOfDay(12 + minute / 60.0f);
            for (int frame = 0; frame < 120; frame++) { stove.update(); food.update(); }
        }
        System.out.println("THERMAL minute=" + minute + " heat=" + food.getHeat() + " cook=" + food.getCookingTime()
            + " required=" + food.getMinutesToCook() + " temperature=" + container.getTemprature());
        check("native_food_update_cooks_exact_item", food.isCooked() && !food.isBurnt()
            && food.getCookingTime() > food.getMinutesToCook());
        var state = SAOCooking.heatState(body, "cook/1");
        check("native_heat_read_does_not_grant_xp", Boolean.TRUE.equals(state.rawget("progressed"))
            && body.getXp().getXP(PerkFactory.Perks.Cooking) == beforeXp
            && other.getXp().getXP(PerkFactory.Perks.Cooking) == otherXp);
        state.rawset("cookingTime", 9999.0); state.rawset("credited", true);
        check("heat_observation_detached", !Double.valueOf(9999).equals(SAOCooking.heatState(body, "cook/1").rawget("cookingTime"))
            && Boolean.FALSE.equals(SAOCooking.heatState(body, "cook/1").rawget("credited")));
        check("different_body_cannot_consume_native_result", SAOCooking.completeHeat(other, "cook/1") == null);
        var completed = SAOCooking.completeHeat(body, "cook/1");
        float credited = body.getXp().getXP(PerkFactory.Perks.Cooking);
        check("completion_grants_native_xp", completed != null && Boolean.TRUE.equals(completed.rawget("credited"))
            && credited > beforeXp && "Original Cook".equals(food.getChef()));
        SAOCooking.completeHeat(body, "cook/1"); SAOCooking.heatState(body, "cook/1");
        check("completion_xp_once", body.getXp().getXP(PerkFactory.Perks.Cooking) == credited);
        for (int frame = 0; frame < 200; frame++) food.update();
        check("restored_chef_does_not_credit_other_player", other.getXp().getXP(PerkFactory.Perks.Cooking) == otherXp);
        container.DoRemoveItem(food); body.getInventory().AddItem(food);
        check("retrieved_food_cannot_reconsume_heat", SAOCooking.completeHeat(body, "cook/1") == null);
        SAOCooking.clearHeat(body, "cook/1");
        check("native_credit_survives_binding_release", food.getModData().rawget("SAOCookingCredit") != null
            && food.getModData().rawget("SAOCookingBinding") == null);
        var bytes = java.nio.ByteBuffer.allocate(1024 * 1024);
        food.saveWithSize(bytes, false); bytes.flip();
        var restored = (Food) zombie.inventory.InventoryItem.loadItem(bytes, zombie.iso.IsoWorld.getWorldVersion());
        check("native_save_load_retains_credit_identity", restored != null && restored.isCooked()
            && restored.getModData().rawget("SAOCookingCredit").equals(food.getModData().rawget("SAOCookingCredit")));
        container.AddItem(restored); SAOCooking.reset();
        check("reload_cannot_recredit_cooked_item", !SAOCooking.beginHeat(body, "cook/reloaded", restored, stove, container)
            && SAOCooking.completeHeat(body, "cook/1") == null
            && body.getXp().getXP(PerkFactory.Perks.Cooking) == credited);
        container.DoRemoveItem(restored);
        var burn = (Food) zombie.inventory.InventoryItemFactory.CreateItem("Base.MuttonChop");
        burn.setChef("Burn Cook"); container.AddItem(burn);
        check("second_raw_food_can_bind", SAOCooking.beginHeat(body, "cook/burn", burn, stove, container));
        for (int elapsed = 1; elapsed < 300 && !burn.isBurnt(); elapsed++) {
            zombie.GameTime.getInstance().setTimeOfDay(14 + elapsed / 60.0f);
            for (int frame = 0; frame < 120; frame++) { stove.update(); burn.update(); }
        }
        check("native_burn_progression_not_completion", burn.isBurnt() && SAOCooking.completeHeat(body, "cook/burn") == null
            && body.getXp().getXP(PerkFactory.Perks.Cooking) == credited);
        SAOCooking.clearHeat(body, "cook/burn"); container.DoRemoveItem(burn);
        var toastDefinition = itemMethod.invoke(null, Path.of(args[0]), module, dictionary, "food.txt", "Toast", (short) 2802);
        var bread = (Food) itemMethod.invoke(null, Path.of(args[0]), module, dictionary, "food.txt", "BreadSlices", (short) 2803);
        container.AddItem(bread);
        check("ordinary_replacement_food_may_be_prepared", bread.getReplaceOnCooked() != null
            && SAOCooking.beginHeat(body, "cook/toast", bread, stove, container));
        for (int elapsed = 1; elapsed < 90 && container.getItems().contains(bread); elapsed++) {
            zombie.GameTime.getInstance().setTimeOfDay(19 + elapsed / 60.0f);
            for (int frame = 0; frame < 120 && container.getItems().contains(bread); frame++) { stove.update(); bread.update(); }
        }
        boolean toastPresent = false;
        for (var item : container.getItems()) if ("Base.Toast".equals(item.getFullType())) toastPresent = true;
        check("native_replacement_happens_but_unbound_result_has_no_credit", !container.getItems().contains(bread) && toastPresent
            && SAOCooking.heatState(body, "cook/toast") == null && SAOCooking.completeHeat(body, "cook/toast") == null
            && body.getXp().getXP(PerkFactory.Perks.Cooking) == credited);
        SAOCooking.reset();
        square.chunk.removeGeneratorPos(10, 20, 0); stove.update();
        check("native_power_loss_deactivates_stove", !container.isPowered() && !stove.Activated());
        stove.setActivated(false);
        float hot = stove.getCurrentTemperature();
        for (int i = 0; i < 200; i++) stove.update();
        check("native_shutdown_cools", !stove.Activated() && stove.getCurrentTemperature() < hot);
        System.out.println("COOKING_NATIVE_OK");
        System.exit(0);
    }
}
