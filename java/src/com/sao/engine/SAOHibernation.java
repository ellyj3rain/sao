package com.sao.engine;

import zombie.characters.CharacterStat;
import zombie.characters.IsoPlayer;
import zombie.inventory.InventoryItem;
import zombie.inventory.types.Food;

/**
 * The persistent person, across body teardowns. hibernate() packs what the
 * body carries and is; awaken() restores it onto a fresh shell and runs the
 * dormant simulation for the hours nobody was looking.
 *
 * New snapshots use the complete native v4 envelope. Native v3 and legacy
 * v1/v2 snapshots remain readable within the state each format carried.
 *
 * Dormant metabolism: hunger +0.012/h, thirst +0.020/h (approximate engine
 * rates), offset by eating carried food (largest first, the way [A8]
 * eats), capped at 0.95 - nobody dies off-screen in v1; long absences
 * produce desperate reunions instead of quiet deletions. Direct stat and
 * inventory mutation here is the architecture's sanctioned unloaded-world
 * mode, not a bypass of the vanilla-action law (which governs the LOADED
 * world only).
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

            // Dormant metabolism: time passes, the person eats what they had.
            double hungerAfter = hunger + elapsedHours * HUNGER_PER_HOUR;
            double thirstAfter = elapsedHours > 0 ? Math.min(DORMANT_CAP,
                thirst + elapsedHours * THIRST_PER_HOUR) : thirst;
            int mealsEaten = 0;
            while (elapsedHours > 0 && hungerAfter > 0.5f) {
                InventoryItem meal = SAONeeds.bestCarriedFood(shell);
                if (meal == null) {
                    break;
                }
                float fill = Math.abs(((Food) meal).getHungChange());
                if (shell.getPrimaryHandItem() == meal) shell.setPrimaryHandItem(null);
                if (shell.getSecondaryHandItem() == meal) shell.setSecondaryHandItem(null);
                meal.getContainer().Remove(meal);
                hungerAfter = Math.max(0.0f, hungerAfter - Math.max(0.05f, fill));
                mealsEaten++;
            }
            if (elapsedHours > 0) hungerAfter = Math.min(DORMANT_CAP, hungerAfter);
            // v2 truth: the dormant DRINK too - carried drinkables offset
            // thirst the way meals offset hunger ([A24] ledgered gap).
            int drinksDrunk = 0;
            while (elapsedHours > 0 && thirstAfter > 0.5f) {
                InventoryItem drink = SAONeeds.bestCarriedDrink(shell);
                if (drink == null) {
                    break;
                }
                float amount = 0.3f;
                var fc = drink.getFluidContainer();
                if (fc != null) {
                    amount = Math.max(0.1f, Math.min(0.5f, fc.getAmount()));
                    fc.Empty();
                }
                thirstAfter = Math.max(0.0f, thirstAfter - amount);
                drinksDrunk++;
                if (drinksDrunk >= 6) {
                    break;
                }
            }
            zombie.characters.Stats stats = shell.getStats();
            stats.set(CharacterStat.HUNGER, (float) hungerAfter);
            stats.set(CharacterStat.THIRST, (float) thirstAfter);

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
            return "AWAKENED items=" + restored + " mealsDormant=" + mealsEaten
                + " drinksDormant=" + drinksDrunk
                + " hunger=" + String.format(java.util.Locale.ROOT, "%.2f", hungerAfter)
                + " thirst=" + String.format(java.util.Locale.ROOT, "%.2f", thirstAfter);
        } catch (Throwable throwable) {
            return "AWAKEN_FAILED " + throwable;
        }
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
