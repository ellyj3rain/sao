package com.sao.engine;

import zombie.characters.IsoGameCharacter;
import zombie.inventory.InventoryItem;
import zombie.inventory.ItemContainer;
import zombie.iso.IsoCell;
import zombie.iso.IsoGridSquare;
import zombie.iso.IsoObject;
import zombie.iso.objects.IsoBarricade;
import zombie.iso.objects.interfaces.BarricadeAble;
import zombie.scripting.objects.ItemTag;

/**
 * [C44] What a survivor can actually build, starting with the smallest
 * thing that is really building: boarding a window.
 *
 * The operator's ruling (DR-036, Crucible 2026-09-07): nothing is
 * forced. The county is not handed fortifications and the fast-forward
 * does not author them. People are given what they need and either they
 * manage it or they do not; if they never manage it, that is a finding
 * about the systems rather than a reason to place a barricade by hand.
 *
 * So this class answers two questions and performs one act, and every
 * one of them is the game's own:
 *
 *   is there anything here to board   a BarricadeAble on a nearby
 *                                     square that is not already full
 *   could this person do it           the exact requirements
 *                                     ISBarricadeAction.isValid checks -
 *                                     a hammer, a plank, two nails
 *   board it                          IsoBarricade.AddBarricadeToObject
 *                                     and addPlank, the same calls the
 *                                     player's own action makes
 *
 * NOTHING IS CONJURED. The plank and the two nails leave the person's
 * inventory, because a barricade that costs nothing is a decoration and
 * the whole point is to find out whether the county can gather what it
 * needs and use it.
 */
public final class SAOBuild {

    /** ISBarricadeAction's own figures and tags, read off the shipped
     *  Lua and checked against the jar: the action wants a HAMMER-tagged
     *  tool equipped, a Plank equipped, and two Base.Nails. */
    public static final int NAILS_PER_PLANK = 2;

    private SAOBuild() {
    }

    private static IsoCell cellOf(IsoGameCharacter person) {
        IsoGridSquare here = person.getCurrentSquare();
        return here == null ? null : here.getCell();
    }

    /** Everything the shipped action wants before it will start. */
    public static boolean canBoard(IsoGameCharacter person) {
        if (person == null) {
            return false;
        }
        try {
            ItemContainer bag = person.getInventory();
            if (bag == null) {
                return false;
            }
            return person.hasEquippedTag(ItemTag.HAMMER)
                && person.hasEquipped("Plank")
                && bag.getNumberOfItem("Base.Nails", true) >= NAILS_PER_PLANK;
        } catch (Throwable throwable) {
            return false;
        }
    }

    /** Has this person got the makings anywhere on them, equipped or
     *  not? What they are holding is the controller's business to fix;
     *  this is whether it is worth walking to a window at all. */
    public static boolean carriesTheMakings(IsoGameCharacter person) {
        if (person == null) {
            return false;
        }
        try {
            ItemContainer bag = person.getInventory();
            if (bag == null) {
                return false;
            }
            return bag.getNumberOfItem("Base.Plank", true) >= 1
                && bag.getNumberOfItem("Base.Nails", true) >= NAILS_PER_PLANK
                && bag.getFirstTagRecurse(ItemTag.HAMMER) != null;
        } catch (Throwable throwable) {
            return false;
        }
    }

    /** Put the hammer and a plank in their hands, the way the player's
     *  own menu does before the action runs. Reports whether both are
     *  there afterwards. */
    public static boolean readyToBoard(IsoGameCharacter person) {
        if (person == null) {
            return false;
        }
        try {
            ItemContainer bag = person.getInventory();
            if (bag == null) {
                return false;
            }
            if (!person.hasEquippedTag(ItemTag.HAMMER)) {
                InventoryItem hammer = bag.getFirstTagRecurse(ItemTag.HAMMER);
                if (hammer != null) {
                    person.setSecondaryHandItem(hammer);
                }
            }
            if (!person.hasEquipped("Plank")) {
                InventoryItem plank = bag.getFirstTypeRecurse("Base.Plank");
                if (plank != null) {
                    person.setPrimaryHandItem(plank);
                }
            }
            return canBoard(person);
        } catch (Throwable throwable) {
            return false;
        }
    }

    private static boolean boardable(IsoObject object, IsoGameCharacter person) {
        if (!(object instanceof BarricadeAble able)) {
            return false;
        }
        if (object.getObjectIndex() == -1) {
            return false;
        }
        IsoBarricade already = IsoBarricade.GetBarricadeForCharacter(able, person);
        return already == null || already.canAddPlank();
    }

    /**
     * The nearest window or door this person could put a plank on,
     * inside the box handed in - which is the caller's claim, so nobody
     * boards up somebody else's house. Returns "x,y,z" or "".
     */
    public static String findBoardable(IsoGameCharacter person, int minX, int minY,
                                       int maxX, int maxY, int z, int reach) {
        if (person == null) {
            return "";
        }
        try {
            IsoCell cell = cellOf(person);
            if (cell == null) {
                return "";
            }
            int px = (int) person.getX();
            int py = (int) person.getY();
            int fromX = Math.max(minX, px - reach);
            int toX = Math.min(maxX, px + reach);
            int fromY = Math.max(minY, py - reach);
            int toY = Math.min(maxY, py + reach);
            String best = "";
            int bestDistance = Integer.MAX_VALUE;
            for (int x = fromX; x <= toX; x++) {
                for (int y = fromY; y <= toY; y++) {
                    IsoGridSquare square = cell.getGridSquare(x, y, z);
                    if (square == null) {
                        continue;
                    }
                    for (int i = 0; i < square.getObjects().size(); i++) {
                        IsoObject object = square.getObjects().get(i);
                        if (!boardable(object, person)) {
                            continue;
                        }
                        int dx = x - px;
                        int dy = y - py;
                        int distance = dx * dx + dy * dy;
                        if (distance < bestDistance) {
                            bestDistance = distance;
                            best = x + "," + y + "," + z;
                        }
                        break;
                    }
                }
            }
            return best;
        } catch (Throwable throwable) {
            return "";
        }
    }

    /**
     * Put one plank on the window at (x,y,z), through the engine's own
     * calls, and pay for it out of the person's inventory. Returns the
     * plank count now on it, 0 when nothing happened.
     */
    public static int board(IsoGameCharacter person, int x, int y, int z) {
        if (!canBoard(person)) {
            return 0;
        }
        try {
            IsoCell cell = cellOf(person);
            if (cell == null) {
                return 0;
            }
            IsoGridSquare square = cell.getGridSquare(x, y, z);
            if (square == null) {
                return 0;
            }
            for (int i = 0; i < square.getObjects().size(); i++) {
                IsoObject object = square.getObjects().get(i);
                if (!boardable(object, person)) {
                    continue;
                }
                BarricadeAble able = (BarricadeAble) object;
                IsoBarricade barricade = IsoBarricade.GetBarricadeForCharacter(able, person);
                if (barricade == null) {
                    barricade = IsoBarricade.AddBarricadeToObject(able, person);
                }
                if (barricade == null) {
                    return 0;
                }
                ItemContainer bag = person.getInventory();
                InventoryItem plank = bag.getFirstTypeRecurse("Base.Plank");
                if (plank == null) {
                    return 0;
                }
                barricade.addPlank(person, plank);
                // Paid for. The engine's own action consumes the plank
                // through the same add; the nails are ours to take, and
                // a barricade that costs nothing is a decoration.
                bag.Remove(plank);
                for (int n = 0; n < NAILS_PER_PLANK; n++) {
                    InventoryItem nail = bag.getFirstTypeRecurse("Base.Nails");
                    if (nail != null) {
                        bag.Remove(nail);
                    }
                }
                return barricade.getNumPlanks();
            }
            return 0;
        } catch (Throwable throwable) {
            return 0;
        }
    }
}
