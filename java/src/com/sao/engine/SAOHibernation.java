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
 * Format (one line, record-storable):
 *   v1;primary=<fullType|->;h=<hunger>;t=<thirst>;hp=<health>;items=<ft*n,ft*n,...>
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

    /** [B50] One item type, made safe to pack into the hibernation
     *  string.
     *
     *  This protocol is `;`-fielded, `,`-separated, and uses `@` for a
     *  condition and `*` for a count - and `getFullType()` is whatever
     *  the mod that added the item chose to call it. A single one of
     *  those characters in a type name corrupts the row, and the
     *  restore side drops what it cannot parse in silence
     *  (`if (star <= 0) continue`).
     *
     *  This one goes into the SAVE, so a corrupted row is not a bad
     *  frame that the next tick replaces - it is somebody's inventory,
     *  gone, with nothing said.
     */
    private static String packType(String type) {
        if (type == null) {
            return "-";
        }
        return type.replace(';', '_').replace(',', '_')
            .replace('*', '_').replace('@', '_').replace('=', '_');
    }

    public static String hibernate(IsoPlayer shell) {
        try {
            StringBuilder out = new StringBuilder(200);
            out.append("v2;primary=");
            InventoryItem primary = shell.getPrimaryHandItem();
            out.append(primary == null ? "-" : packType(primary.getFullType()));
            zombie.characters.Stats stats = shell.getStats();
            out.append(";h=").append(stats.get(CharacterStat.HUNGER));
            out.append(";t=").append(stats.get(CharacterStat.THIRST));
            out.append(";hp=").append(shell.getBodyDamage().getHealth());
            // [B10] The wound rides with them: a bite and an infected
            // wound are facts about a person, not about a cell.
            try {
                out.append(";bit=")
                   .append(shell.getBodyDamage().getNumPartsBitten());
                out.append(";inf=")
                   .append(shell.getBodyDamage()
                       .getGeneralWoundInfectionLevel());
            } catch (Throwable ignored) {
            }
            // v2: which garments were ON THE BODY - spares stay packed.
            out.append(";worn=");
            boolean firstWorn = true;
            java.util.ArrayList<InventoryItem> items = shell.getInventory().getItems();
            for (int i = 0; i < items.size(); i++) {
                InventoryItem item = items.get(i);
                if (item instanceof zombie.inventory.types.Clothing clothing
                    && (clothing.isWorn() || clothing.isEquipped())
                    && item.getFullType() != null) {
                    if (!firstWorn) {
                        out.append(',');
                    }
                    firstWorn = false;
                    out.append(packType(item.getFullType()));
                }
            }
            // v2: items carry their CONDITION (percent of max) so a worn
            // axe returns worn. Grouped by type@condPct.
            out.append(";items=");
            java.util.Map<String, Integer> counts = new java.util.LinkedHashMap<>();
            for (int i = 0; i < items.size(); i++) {
                InventoryItem item = items.get(i);
                String type = item.getFullType();
                if (type == null) {
                    continue;
                }
                int condPct = 100;
                try {
                    int max = item.getConditionMax();
                    if (max > 0) {
                        condPct = Math.max(0, Math.min(100,
                            (int) (item.getCondition() * 100.0f / max)));
                    }
                } catch (Throwable ignored) {
                }
                counts.merge(packType(type) + "@" + condPct, 1,
                    Integer::sum);
            }
            boolean first = true;
            for (java.util.Map.Entry<String, Integer> entry : counts.entrySet()) {
                if (!first) {
                    out.append(',');
                }
                first = false;
                out.append(entry.getKey()).append('*').append(entry.getValue());
            }
            return out.toString();
        } catch (Throwable throwable) {
            return "";
        }
    }

    /** Restore a packed snapshot onto a fresh shell and metabolize the
     * elapsed dormant hours. Returns a short journal of what happened. */
    public static String awaken(IsoPlayer shell, String packed, double elapsedHours) {
        try {
            boolean v2 = packed != null && packed.startsWith("v2;");
            if (packed == null || (!v2 && !packed.startsWith("v1;"))) {
                return "NO_SNAPSHOT";
            }
            String primaryType = "-";
            float hunger = 0.0f;
            float thirst = 0.0f;
            float health = -1.0f;
            int bitten = 0;
            float infection = 0.0f;
            String itemsPart = "";
            String wornPart = "";
            for (String field : packed.substring(3).split(";")) {
                int eq = field.indexOf('=');
                if (eq <= 0) {
                    continue;
                }
                String key = field.substring(0, eq);
                String value = field.substring(eq + 1);
                switch (key) {
                    case "primary" -> primaryType = value;
                    case "h" -> hunger = parseFloat(value, 0.0f);
                    case "t" -> thirst = parseFloat(value, 0.0f);
                    case "hp" -> health = parseFloat(value, -1.0f);
                    case "bit" -> bitten = (int) parseFloat(value, 0.0f);
                    case "inf" -> infection = parseFloat(value, 0.0f);
                    case "items" -> itemsPart = value;
                    case "worn" -> wornPart = value;
                    default -> { }
                }
            }

            // Restore the pack. v2 entries are type@condPct; v1 are bare
            // types - both parse here (tolerance: old records awaken).
            int restored = 0;
            if (!itemsPart.isEmpty()) {
                for (String pair : itemsPart.split(",")) {
                    int star = pair.lastIndexOf('*');
                    if (star <= 0) {
                        continue;
                    }
                    String typeAndCond = pair.substring(0, star);
                    int count = (int) parseFloat(pair.substring(star + 1), 0.0f);
                    String type = typeAndCond;
                    int condPct = -1;
                    int at = typeAndCond.lastIndexOf('@');
                    if (at > 0) {
                        String condRaw = typeAndCond.substring(at + 1);
                        boolean numeric = !condRaw.isEmpty();
                        for (int k = 0; k < condRaw.length(); k++) {
                            if (!Character.isDigit(condRaw.charAt(k))) {
                                numeric = false;
                                break;
                            }
                        }
                        if (numeric) {
                            type = typeAndCond.substring(0, at);
                            condPct = (int) parseFloat(condRaw, -1.0f);
                        }
                    }
                    for (int i = 0; i < count; i++) {
                        InventoryItem added = shell.getInventory().AddItem(type);
                        if (added != null) {
                            restored++;
                            if (condPct >= 0) {
                                try {
                                    int max = added.getConditionMax();
                                    if (max > 0) {
                                        added.setCondition(
                                            Math.max(0, condPct * max / 100));
                                    }
                                } catch (Throwable ignored) {
                                }
                            }
                        }
                    }
                }
            }

            // Dormant metabolism: time passes, the person eats what they had.
            float hungerAfter = hunger + (float) elapsedHours * HUNGER_PER_HOUR;
            float thirstAfter = Math.min(DORMANT_CAP,
                thirst + (float) elapsedHours * THIRST_PER_HOUR);
            int mealsEaten = 0;
            while (hungerAfter > 0.5f) {
                InventoryItem meal = SAONeeds.bestCarriedFood(shell);
                if (meal == null) {
                    break;
                }
                float fill = Math.abs(((Food) meal).getHungChange());
                shell.getInventory().Remove(meal);
                hungerAfter = Math.max(0.0f, hungerAfter - Math.max(0.05f, fill));
                mealsEaten++;
            }
            hungerAfter = Math.min(DORMANT_CAP, hungerAfter);
            // v2 truth: the dormant DRINK too - carried drinkables offset
            // thirst the way meals offset hunger ([A24] ledgered gap).
            int drinksDrunk = 0;
            while (thirstAfter > 0.5f) {
                InventoryItem drink = SAONeeds.bestCarriedDrink(shell);
                if (drink == null) {
                    break;
                }
                float amount = 0.3f;
                try {
                    var fc = drink.getFluidContainer();
                    if (fc != null) {
                        amount = Math.max(0.1f, Math.min(0.5f, fc.getAmount()));
                        fc.Empty();
                    }
                } catch (Throwable ignored) {
                }
                thirstAfter = Math.max(0.0f, thirstAfter - amount);
                drinksDrunk++;
                if (drinksDrunk >= 6) {
                    break;
                }
            }
            zombie.characters.Stats stats = shell.getStats();
            stats.set(CharacterStat.HUNGER, hungerAfter);
            stats.set(CharacterStat.THIRST, thirstAfter);

            // Wounds do not heal by being unobserved.
            // [B10] The wound comes back with them, through the engine's
            // own setters - restoring what was true, never inventing what
            // was not. Old packs carry neither field and awaken as before.
            try {
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
            } catch (Throwable ignored) {
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
                try {
                    zombie.scripting.objects.ItemBodyLocation location = item.getBodyLocation();
                    if (location != null
                        && item instanceof zombie.inventory.types.Clothing
                        && (!v2 || wornTypes.contains(item.getFullType()))) {
                        shell.setWornItem(location, item);
                    }
                } catch (Throwable ignored) {
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
            return "AWAKENED items=" + restored + " mealsDormant=" + mealsEaten
                + " drinksDormant=" + drinksDrunk
                + " hunger=" + String.format(java.util.Locale.ROOT, "%.2f", hungerAfter)
                + " thirst=" + String.format(java.util.Locale.ROOT, "%.2f", thirstAfter);
        } catch (Throwable throwable) {
            return "AWAKEN_FAILED " + throwable;
        }
    }

    private static float parseFloat(String value, float fallback) {
        try {
            return Float.parseFloat(value);
        } catch (Throwable throwable) {
            return fallback;
        }
    }
}
