package com.sao.engine;

import zombie.characters.IsoGameCharacter;
import zombie.inventory.InventoryItem;
import zombie.inventory.ItemContainer;
import zombie.inventory.types.HandWeapon;

/**
 * Equipment selection from items the survivor actually carries — typed port of
 * the reference's equipBestMelee scoring. No invention: the survivor equips
 * what it has, never what it "should" have.
 */
public final class SAOEquipment {

    private SAOEquipment() {
    }

    /** One measure of a melee weapon's worth, shared by hand and hunt. */
    public static float meleeScore(InventoryItem item) {
        if (!(item instanceof HandWeapon weapon)
            || weapon.isRanged()
            || weapon.isBroken()) {
            return Float.NEGATIVE_INFINITY;
        }
        int conditionMax = weapon.getConditionMax();
        float condition = conditionMax <= 0
            ? 0.0f
            : weapon.getCondition() / (float) conditionMax;
        float averageDamage = (weapon.getMinDamage() + weapon.getMaxDamage()) * 0.5f;
        return averageDamage * 10.0f
            + condition * 5.0f
            + weapon.getMaxRange()
            + weapon.getBaseSpeed()
            + weapon.getCriticalChance() * 0.02f;
    }

    public static String equipBestMelee(IsoGameCharacter body) {
        ItemContainer inventory = body.getInventory();
        HandWeapon best = null;
        float bestScore = Float.NEGATIVE_INFINITY;
        for (InventoryItem item : inventory.getItems()) {
            float score = meleeScore(item);
            if (score > bestScore && item instanceof HandWeapon weapon) {
                best = weapon;
                bestScore = score;
            }
        }

        if (best == null) {
            // F-043: stripping hands here predates the ranged era - a
            // survivor whose only weapon is a firearm was left BARE-
            // HANDED by every take/meal close-out. No melee carried
            // means KEEP WHAT YOU HOLD; empty hands only if the hands
            // were already empty.
            return "NO_MELEE_WEAPON";
        }
        body.setPrimaryHandItem(best);
        body.setSecondaryHandItem(best.isTwoHandWeapon() ? best : null);
        body.resetModelNextFrame();
        return "EQUIPPED " + best.getFullType() + " score=" + bestScore;
    }

    /** Equip the best LOADED firearm from the pack, or report none. The
     * measure is raw damage - at doctrine ranges, spread math is the
     * engine's business, not ours. */
    public static String equipBestRanged(IsoGameCharacter body) {
        ItemContainer inventory = body.getInventory();
        HandWeapon best = null;
        float bestScore = Float.NEGATIVE_INFINITY;
        for (InventoryItem item : inventory.getItems()) {
            if (!(item instanceof HandWeapon weapon)
                || !weapon.isRanged()
                || weapon.isBroken()) {
                continue;
            }
            if (com.sao.engine.SAOCombat.ammoCount(weapon) <= 0) {
                continue;
            }
            float score = (weapon.getMinDamage() + weapon.getMaxDamage()) * 0.5f;
            if (score > bestScore) {
                best = weapon;
                bestScore = score;
            }
        }
        if (best == null) {
            return "NO_READY_RANGED";
        }
        body.setPrimaryHandItem(best);
        body.setSecondaryHandItem(best.isTwoHandWeapon() ? best : null);
        body.resetModelNextFrame();
        return "EQUIPPED_RANGED " + best.getFullType();
    }

    /** Adds one item by full type; returns what happened. */
    public static String addItem(IsoGameCharacter body, String fullType) {
        InventoryItem item = body.getInventory().AddItem(fullType);
        return item == null ? "ADD_FAILED " + fullType : "ADDED " + item.getFullType();
    }
}
