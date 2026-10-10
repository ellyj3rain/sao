package com.sao.engine;

import zombie.characters.IsoGameCharacter;
import zombie.inventory.InventoryItem;
import zombie.inventory.ItemContainer;
import zombie.iso.IsoCell;
import zombie.iso.IsoGridSquare;
import zombie.iso.IsoObject;
import zombie.iso.LosUtil;
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
 * Inventory and visible target queries support SAO.Build. The Lua owner
 * admits and measures the installed ISBarricadeAction lifecycle.
 *
 *   is there anything here to board   a BarricadeAble on a nearby
 *                                     square that is not already full
 *   could this person do it           the exact requirements
 *                                     ISBarricadeAction.isValid checks -
 *                                     a hammer, a plank, two nails
 * Native completion consumes the plank and nails. Admission never places
 * a barricade or supplies physical completion.
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
            InventoryItem hammer = bag.getFirstTagRecurse(ItemTag.HAMMER);
            InventoryItem plank = bag.getFirstTypeRecurse("Base.Plank");
            if (hammer == null || plank == null) return false;
            // ISBarricadeAction.complete reads its material from the secondary hand.
            person.setPrimaryHandItem(hammer);
            person.setSecondaryHandItem(plank);
            return person.getPrimaryHandItem() == hammer
                && person.getSecondaryHandItem() == plank && canBoard(person);
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

    /** A native sightline from this body, independent of local-player slots. */
    public static boolean canSeeBoardable(IsoGameCharacter person, IsoObject object) {
        if (person == null || object == null) return false;
        try {
            IsoGridSquare here = person.getCurrentSquare();
            IsoGridSquare target = object.getSquare();
            if (here == null || target == null || here.getCell() != target.getCell()
                    || here.getZ() != target.getZ() || !boardable(object, person)) return false;
            // Match IsoGameCharacter.faceThisObject for a native edge:
            // north/west on its square, south/east on the opposite side.
            BarricadeAble edge = (BarricadeAble) object;
            double side = here == target ? -1 : 1;
            boolean primarySide = here == target || here == edge.getOppositeSquare();
            double dx = primarySide ? (edge.getNorth() ? 0 : side) : target.getX() + 0.5 - person.getX();
            double dy = primarySide ? (edge.getNorth() ? side : 0) : target.getY() + 0.5 - person.getY();
            if (!Double.isFinite(dx) || !Double.isFinite(dy)
                    || dx * person.getForwardDirectionX() + dy * person.getForwardDirectionY() < 0) return false;
            LosUtil.TestResults result = LosUtil.lineClear(here.getCell(), here.getX(), here.getY(),
                here.getZ(), target.getX(), target.getY(), target.getZ(), false);
            return result == LosUtil.TestResults.Clear || result == LosUtil.TestResults.ClearThroughOpenDoor
                || result == LosUtil.TestResults.ClearThroughWindow;
        } catch (Throwable throwable) {
            return false;
        }
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
                        if (!canSeeBoardable(person, object)) {
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

    /** Retained bridge signature. Physical work belongs to SAO.Build's native queue. */
    @Deprecated
    public static int board(IsoGameCharacter person, int x, int y, int z) {
        return 0;
    }
}
