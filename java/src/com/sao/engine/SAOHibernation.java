package com.sao.engine;

import zombie.characters.CharacterStat;
import zombie.characters.IsoPlayer;
import zombie.inventory.InventoryItem;
import zombie.inventory.ItemContainer;
import zombie.inventory.types.Food;
import zombie.inventory.types.InventoryContainer;

/**
 * The persistent person, across body teardowns. hibernate() packs what the
 * body carries and is; awaken() restores it onto a fresh shell and runs the
 * dormant simulation for the hours nobody was looking.
 *
 * New snapshots use the complete native v4 envelope. Native v3 and legacy
 * v1/v2 snapshots remain readable within the state each format carried.
 *
 * Dormant metabolism: elapsed demand is reconciled through the engine's own
 * Eat and DrinkFluid methods. Those methods apply partial item use, nutrition,
 * fluid composition and side effects. Food and drink are found recursively in
 * carried containers; current age/spoilage is refreshed before selection.
 * The remaining hunger/thirst debt is capped at 0.95 so nobody disappears
 * silently while unloaded.
 */
public final class SAOHibernation {

    private static final float HUNGER_PER_HOUR = 0.012f;
    private static final float THIRST_PER_HOUR = 0.020f;
    private static final float DORMANT_CAP = 0.95f;

    private SAOHibernation() {
    }

    /** Native v4 is the only new writer; v1-v3 remain readers. */
    public static String hibernate(IsoPlayer shell) {
        try {
            return SAONativeSnapshot.capture(shell);
        } catch (Throwable throwable) {
            return "";
        }
    }

    /** Check a snapshot before a fresh body or its inventory is changed. */
    public static boolean validate(String packed) {
        try {
            if (SAONativeSnapshot.isNative(packed)) {
                return SAONativeSnapshot.validate(packed);
            }
            parseLegacy(packed);
            return true;
        } catch (Throwable throwable) {
            return false;
        }
    }

    /** Restore a packed snapshot onto a fresh shell and metabolize the
     * elapsed dormant hours. Returns a short journal of what happened. */
    public static String awaken(IsoPlayer shell, String packed, double elapsedHours) {
        try {
            if (packed == null || packed.isEmpty()) return "NO_SNAPSHOT";
            if (shell == null || !Double.isFinite(elapsedHours) || elapsedHours < 0
                    || !validate(packed)) {
                return "AWAKEN_FAILED invalid snapshot or elapsed time";
            }
            boolean nativeSnapshot = SAONativeSnapshot.isNative(packed);
            boolean v2 = packed.startsWith("v2;");
            LegacySnapshot legacy = nativeSnapshot ? null : parseLegacy(packed);
            String primaryType = legacy == null ? "-" : legacy.fields.get("primary");
            float health = legacy == null ? -1 : finiteFloat(legacy.fields.get("hp"));
            int bitten = legacy == null ? 0 : nonnegativeInt(legacy.fields.getOrDefault("bit", "0"));
            float infection = legacy == null ? 0 : finiteFloat(legacy.fields.getOrDefault("inf", "0"));
            String wornPart = legacy == null ? "" : legacy.fields.getOrDefault("worn", "");
            int restored = 0;
            if (nativeSnapshot) {
                restored = SAONativeSnapshot.restore(shell, packed);
                if (restored < 0) throw new IllegalStateException("negative native restore count");
            } else {
                for (LegacyItem entry : legacy.items) {
                    for (int i = 0; i < entry.count; i++) {
                        InventoryItem added = shell.getInventory().AddItem(entry.type);
                        if (added == null) {
                            throw new IllegalStateException("legacy item type unavailable: " + entry.type);
                        }
                        restored++;
                        if (entry.condition >= 0 && added.getConditionMax() > 0) {
                            added.setCondition(entry.condition * added.getConditionMax() / 100);
                        }
                    }
                }
            }
            float hunger = nativeSnapshot ? shell.getStats().get(CharacterStat.HUNGER)
                : finiteFloat(legacy.fields.get("h"));
            float thirst = nativeSnapshot ? shell.getStats().get(CharacterStat.THIRST)
                : finiteFloat(legacy.fields.get("t"));

            // Dormant metabolism: retain demand above the display/stat cap
            // while resources are reconciled. This makes one 48-hour wake and
            // two 24-hour wakes consume the same quantity when their event
            // history is otherwise equal.
            double hungerAfter = hunger + elapsedHours * HUNGER_PER_HOUR;
            double thirstAfter = thirst + elapsedHours * THIRST_PER_HOUR;
            int foodActions = 0;
            double foodHunger = 0.0;
            double caloriesBefore = shell.getNutrition().getCalories();
            shell.getStats().set(CharacterStat.HUNGER,
                (float) Math.min(1.0, hungerAfter));
            shell.getStats().set(CharacterStat.THIRST,
                (float) Math.min(1.0, thirstAfter));
            while (elapsedHours > 0 && hungerAfter > 0.5f) {
                Food meal = bestDormantFood(shell);
                if (meal == null) break;
                double available = Math.max(0.0, -meal.getHungChange());
                if (available <= 0.000001) break;
                double taken = Math.min(hungerAfter - 0.5, available);
                double base = Math.max(0.000001, Math.abs(meal.getBaseHunger()));
                float engineFraction = (float) Math.min(1.0, taken / base);
                if (!shell.Eat(meal, engineFraction, false)) break;
                hungerAfter -= taken;
                foodHunger += taken;
                foodActions++;
            }
            int drinkActions = 0;
            double fluidConsumed = 0.0;
            while (elapsedHours > 0 && thirstAfter > 0.5f) {
                InventoryItem drink = bestDormantDrink(shell);
                if (drink == null) break;
                var fluids = drink.getFluidContainer();
                float amountBefore = fluids.getAmount();
                double available = fluidRelief(fluids);
                if (amountBefore <= 0.000001f || available <= 0.000001) break;
                float engineFraction = (float) Math.min(1.0,
                    (thirstAfter - 0.5) / available);
                if (!shell.DrinkFluid(drink, engineFraction, false)) break;
                float consumed = Math.max(0.0f, amountBefore - fluids.getAmount());
                if (consumed <= 0.000001f) break;
                double relief = available * consumed / amountBefore;
                thirstAfter -= relief;
                fluidConsumed += consumed;
                drinkActions++;
            }
            zombie.characters.Stats stats = shell.getStats();
            hungerAfter = Math.max(0.0, Math.min(DORMANT_CAP, hungerAfter));
            thirstAfter = Math.max(0.0, Math.min(DORMANT_CAP, thirstAfter));
            stats.set(CharacterStat.HUNGER, (float) hungerAfter);
            stats.set(CharacterStat.THIRST, (float) thirstAfter);
            double caloriesGained = shell.getNutrition().getCalories() - caloriesBefore;

            // Native restore already restored wounds, clothing and equipment.
            // Only old snapshots need their original coarse reconstruction.
            if (!nativeSnapshot) {
                // Wounds do not heal by being unobserved.
                // [B10] The wound comes back with them, through the engine's
                // own setters - restoring what was true, never inventing what
                // was not. Old packs carry neither field and awaken as before.
                if (infection > 0.0f) {
                    for (zombie.characters.BodyDamage.BodyPartType type
                            : zombie.characters.BodyDamage.BodyPartType.values()) {
                        zombie.characters.BodyDamage.BodyPart part =
                            shell.getBodyDamage().getBodyPart(type);
                        if (part != null && part.bandaged()) {
                            part.setWoundInfectionLevel(infection);
                            break;
                        }
                    }
                }
                if (bitten > 0) {
                    zombie.characters.BodyDamage.BodyPart arm =
                        shell.getBodyDamage().getBodyPart(
                            zombie.characters.BodyDamage.BodyPartType.ForeArm_L);
                    if (arm != null) {
                        arm.SetBitten(true);
                    }
                }
                if (health >= 0.0f && health < shell.getBodyDamage().getHealth()) {
                    shell.getBodyDamage().setOverallBodyHealth(health);
                }

                // The body remembers its clothes. v2: only the garments that
                // were ON THE BODY go back on - spares stay in the pack.
                // v1 fallback: every located garment (the old behavior).
                java.util.Set<String> wornTypes = new java.util.HashSet<>();
                if (!wornPart.isEmpty()) {
                    for (String w : wornPart.split(",")) {
                        if (!w.isEmpty()) {
                            wornTypes.add(w);
                        }
                    }
                }
                java.util.ArrayList<InventoryItem> restoredItems = shell.getInventory().getItems();
                for (int i = 0; i < restoredItems.size(); i++) {
                    InventoryItem item = restoredItems.get(i);
                    zombie.scripting.objects.ItemBodyLocation location = item.getBodyLocation();
                    if (location != null
                        && item instanceof zombie.inventory.types.Clothing
                        && (!v2 || wornTypes.contains(item.getFullType()))) {
                        shell.setWornItem(location, item);
                    }
                }
                shell.resetModelNextFrame();

                // The hand remembers its tool.
                if (!"-".equals(primaryType)) {
                    java.util.ArrayList<InventoryItem> items = shell.getInventory().getItems();
                    for (int i = 0; i < items.size(); i++) {
                        InventoryItem item = items.get(i);
                        if (primaryType.equals(item.getFullType())) {
                            shell.setPrimaryHandItem(item);
                            if (item instanceof zombie.inventory.types.HandWeapon weapon
                                && weapon.isTwoHandWeapon()) {
                                shell.setSecondaryHandItem(item);
                            }
                            shell.resetModelNextFrame();
                            break;
                        }
                    }
                }
            }
            return "AWAKENED items=" + restored + " foodActions=" + foodActions
                + " foodHunger=" + format3(foodHunger)
                + " drinkActions=" + drinkActions
                + " fluidConsumed=" + format3(fluidConsumed)
                + " caloriesDormant=" + format3(caloriesGained)
                + " hunger=" + String.format(java.util.Locale.ROOT, "%.2f", hungerAfter)
                + " thirst=" + String.format(java.util.Locale.ROOT, "%.2f", thirstAfter);
        } catch (Throwable throwable) {
            return "AWAKEN_FAILED " + throwable;
        }
    }

    private static java.util.List<InventoryItem> carriedItems(IsoPlayer shell) {
        java.util.ArrayList<InventoryItem> found = new java.util.ArrayList<>();
        java.util.Set<ItemContainer> seen = java.util.Collections.newSetFromMap(
            new java.util.IdentityHashMap<>());
        collect(shell.getInventory(), found, seen);
        return found;
    }

    private static void collect(ItemContainer container,
            java.util.List<InventoryItem> found, java.util.Set<ItemContainer> seen) {
        if (container == null || !seen.add(container)) return;
        java.util.ArrayList<InventoryItem> items = container.getItems();
        for (int i = 0; i < items.size(); i++) {
            InventoryItem item = items.get(i);
            found.add(item);
            if (item instanceof InventoryContainer nested) {
                collect(nested.getInventory(), found, seen);
            }
        }
    }

    private static Food bestDormantFood(IsoPlayer shell) {
        Food best = null;
        double bestFill = 0.0;
        for (InventoryItem item : carriedItems(shell)) {
            if (!(item instanceof Food food)) continue;
            try { food.updateAge(); } catch (Throwable ignored) { continue; }
            if (food.isRotten() || food.getPoisonPower() > 0
                    || (food.isbDangerousUncooked() && food.isUncooked())) continue;
            double fill = -food.getHungChange();
            if (fill > bestFill) {
                bestFill = fill;
                best = food;
            }
        }
        return best;
    }

    private static double fluidRelief(
            zombie.entity.components.fluids.FluidContainer fluids) {
        if (fluids == null || fluids.isEmpty() || fluids.isTainted()) return 0.0;
        var properties = fluids.getProperties();
        if (properties == null || properties.getPoison() > 0.0f
                || properties.getThirstChange() >= 0.0f) return 0.0;
        return -properties.getThirstChange();
    }

    private static InventoryItem bestDormantDrink(IsoPlayer shell) {
        InventoryItem best = null;
        double bestRelief = 0.0;
        for (InventoryItem item : carriedItems(shell)) {
            double relief = fluidRelief(item.getFluidContainer());
            if (relief > bestRelief) {
                bestRelief = relief;
                best = item;
            }
        }
        return best;
    }

    private static String format3(double value) {
        return String.format(java.util.Locale.ROOT, "%.3f", value);
    }

    private record LegacyItem(String type, int condition, int count) { }

    private record LegacySnapshot(java.util.Map<String, String> fields,
                                  java.util.List<LegacyItem> items) { }

    private static LegacySnapshot parseLegacy(String packed) {
        if (packed == null || (!packed.startsWith("v1;") && !packed.startsWith("v2;"))) {
            throw new IllegalArgumentException("unknown snapshot version");
        }
        boolean v2 = packed.startsWith("v2;");
        java.util.Map<String, String> fields = new java.util.LinkedHashMap<>();
        java.util.Set<String> allowed = java.util.Set.of(
            "primary", "h", "t", "hp", "items", "bit", "inf", "worn");
        for (String field : packed.substring(3).split(";", -1)) {
            int eq = field.indexOf('=');
            if (eq <= 0 || eq != field.lastIndexOf('=')) {
                throw new IllegalArgumentException("malformed legacy field");
            }
            String key = field.substring(0, eq);
            if (!allowed.contains(key) || fields.putIfAbsent(key, field.substring(eq + 1)) != null) {
                throw new IllegalArgumentException("unknown or duplicate legacy field: " + key);
            }
        }
        for (String key : java.util.List.of("primary", "h", "t", "hp", "items")) {
            if (!fields.containsKey(key)) throw new IllegalArgumentException("missing legacy field: " + key);
        }
        if (v2 != fields.containsKey("worn")) {
            throw new IllegalArgumentException("worn field disagrees with legacy version");
        }
        String primary = fields.get("primary");
        if (!"-".equals(primary)) requireType(primary);
        for (String key : java.util.List.of("h", "t", "hp", "inf")) {
            if (fields.containsKey(key) && finiteFloat(fields.get(key)) < 0) {
                throw new IllegalArgumentException("negative legacy body value: " + key);
            }
        }
        // Early writers allowed these optional wound reads to fail.
        if (fields.containsKey("bit")) nonnegativeInt(fields.get("bit"));
        java.util.List<LegacyItem> items = new java.util.ArrayList<>();
        java.util.Set<String> types = new java.util.HashSet<>();
        java.util.Set<String> groups = new java.util.HashSet<>();
        int total = 0;
        if (!fields.get("items").isEmpty()) {
            for (String pair : fields.get("items").split(",", -1)) {
                int star = pair.indexOf('*');
                if (star <= 0 || star != pair.lastIndexOf('*')) {
                    throw new IllegalArgumentException("malformed legacy item");
                }
                String group = pair.substring(0, star);
                if (!groups.add(group)) throw new IllegalArgumentException("duplicate legacy item group");
                int count = nonnegativeInt(pair.substring(star + 1));
                if (count == 0) throw new IllegalArgumentException("zero legacy item count");
                total = Math.addExact(total, count);
                String type = group;
                int condition = -1;
                if (v2) {
                    int at = group.indexOf('@');
                    if (at <= 0 || at != group.lastIndexOf('@')) {
                        throw new IllegalArgumentException("missing or malformed legacy condition");
                    }
                    type = group.substring(0, at);
                    condition = nonnegativeInt(group.substring(at + 1));
                    if (condition > 100) throw new IllegalArgumentException("legacy condition exceeds percent range");
                }
                requireType(type);
                types.add(type);
                items.add(new LegacyItem(type, condition, count));
            }
        }
        if (!"-".equals(primary) && !types.contains(primary)) {
            throw new IllegalArgumentException("legacy hand item absent from inventory");
        }
        if (v2 && !fields.get("worn").isEmpty()) {
            for (String type : fields.get("worn").split(",", -1)) {
                requireType(type);
                // The old writer emitted one type per garment, without deduplication.
                if (!types.contains(type)) {
                    throw new IllegalArgumentException("missing legacy worn item");
                }
            }
        }
        return new LegacySnapshot(fields, items);
    }

    private static void requireType(String type) {
        if (type == null || type.isBlank() || "-".equals(type)) {
            throw new IllegalArgumentException("empty legacy item type");
        }
        for (int i = 0; i < type.length(); i++) {
            char ch = type.charAt(i);
            if (Character.isISOControl(ch) || ";,*@=".indexOf(ch) >= 0) {
                throw new IllegalArgumentException("invalid legacy item type");
            }
        }
    }

    private static float finiteFloat(String value) {
        float parsed = Float.parseFloat(value);
        if (!Float.isFinite(parsed)) throw new IllegalArgumentException("nonfinite legacy body value");
        return parsed;
    }

    private static int nonnegativeInt(String value) {
        if (value.isEmpty()) throw new IllegalArgumentException("empty legacy integer");
        for (int i = 0; i < value.length(); i++) {
            if (value.charAt(i) < '0' || value.charAt(i) > '9') {
                throw new IllegalArgumentException("malformed legacy integer");
            }
        }
        return Integer.parseInt(value);
    }
}
