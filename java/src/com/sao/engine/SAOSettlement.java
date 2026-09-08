package com.sao.engine;

import zombie.characters.IsoPlayer;
import zombie.iso.BuildingDef;
import zombie.iso.IsoCell;
import zombie.iso.areas.IsoBuilding;

/**
 * Base scouting (DR-006 S4): score loaded buildings the way the audited
 * reference did - rooms weigh most, area helps to a cap, water is worth a
 * detour - with minimum gates so a shed never becomes a headquarters, a
 * mild distance penalty so the nearest good building beats a marginally
 * better one across town, and caller-supplied rejection memory.
 *
 * [C48] AND HOW HARD IT IS TO GET INTO, which the score did not know.
 * A place was judged on rooms, area and water alone, so a glass-fronted
 * shop with eleven ways in beat a house with three whenever it had one
 * more room - and the operator's own description of what should emerge
 * (a neighbourhood that becomes gated, choke points read once ground is
 * clear) rests on exactly the fact the scout could not see.
 *
 * It is a TIE-BREAK, not a new weight. Adding a coefficient for ways-in
 * would be inventing a rate at which a door is worth part of a room,
 * and nothing gives that number. What is defensible is narrower and
 * enough: where two places score within one room's worth of each other,
 * the one with fewer ways in wins. The margin is the score's own unit -
 * ROOM_WEIGHT - so it moves if the scoring ever does, and nobody has
 * had to decide what a door is worth.
 */
public final class SAOSettlement {

    private static final int MIN_ROOMS = 4;
    private static final int MIN_AREA = 48;

    /** What a room is worth in the score, named because [C48]'s
     *  tie-break margin is one of them and the two must not drift. */
    private static final double ROOM_WEIGHT = 8.0;

    private SAOSettlement() {
    }

    /**
     * [C48] How many ways there are into a place: the doors and windows
     * on its own squares that a person could come through, counted off
     * the loaded cell. The scout is standing in the neighbourhood, so
     * these buildings are loaded - this reads what is there and never
     * loads anything itself.
     *
     * The same predicate the boarding uses (BarricadeAble), so what the
     * scout counts and what somebody would later have to shut are the
     * same set of things, rather than two ideas of a way in.
     *
     * -1 when it cannot be read, which never wins a tie-break.
     */
    public static int waysIn(IsoCell cell, BuildingDef def) {
        if (cell == null || def == null) {
            return -1;
        }
        try {
            int ways = 0;
            int z = 0;
            for (int x = def.getX(); x < def.getX() + def.getW(); x++) {
                for (int y = def.getY(); y < def.getY() + def.getH(); y++) {
                    zombie.iso.IsoGridSquare square = cell.getGridSquare(x, y, z);
                    if (square == null) {
                        continue;
                    }
                    for (int i = 0; i < square.getObjects().size(); i++) {
                        if (square.getObjects().get(i)
                            instanceof zombie.iso.objects.interfaces.BarricadeAble) {
                            ways++;
                            break;
                        }
                    }
                }
            }
            return ways;
        } catch (Throwable throwable) {
            return -1;
        }
    }

    /**
     * Best candidate near the scout:
     * "bx:by:bw:bh:cx:cy:rooms:area:water:score:ways" or "".
     * rejectedCsv holds "x,y" building keys to skip.
     */
    public static String scout(IsoPlayer shell, String rejectedCsv) {
        try {
            IsoCell cell = shell.getCell();
            if (cell == null) {
                return "";
            }
            java.util.Set<String> rejected = new java.util.HashSet<>();
            if (rejectedCsv != null && !rejectedCsv.isEmpty()) {
                for (String key : rejectedCsv.split(";")) {
                    rejected.add(key);
                }
            }
            float sx = shell.getX();
            float sy = shell.getY();
            IsoBuilding best = null;
            BuildingDef bestDef = null;
            double bestScore = -1.0;
            int bestWays = -1;
            java.util.ArrayList<IsoBuilding> buildings = cell.getBuildingList();
            for (int i = 0; i < buildings.size(); i++) {
                IsoBuilding building = buildings.get(i);
                if (building == null) {
                    continue;
                }
                BuildingDef def = building.getDef();
                if (def == null) {
                    continue;
                }
                int rooms = def.getRoomsNumber();
                int area = def.getArea();
                if (rooms < MIN_ROOMS || area < MIN_AREA) {
                    continue;
                }
                if (rejected.contains(def.getX() + "," + def.getY())) {
                    continue;
                }
                boolean water = false;
                try {
                    water = building.hasWater();
                } catch (Throwable ignored) {
                }
                double centerX = def.getX() + def.getW() / 2.0;
                double centerY = def.getY() + def.getH() / 2.0;
                double dist = Math.sqrt((centerX - sx) * (centerX - sx)
                    + (centerY - sy) * (centerY - sy));
                double score = rooms * ROOM_WEIGHT
                    + Math.min(area, 240) * 0.15
                    + (water ? 15.0 : 0.0)
                    - dist * 0.05;
                // [C48] Counted only when it could matter: reading a
                // building's perimeter is real work, and a place that
                // is not close to the best one will never win a
                // tie-break anyway.
                int ways = -1;
                if (score > bestScore - ROOM_WEIGHT) {
                    ways = waysIn(cell, def);
                }
                boolean better = score > bestScore;
                if (!better && bestWays >= 0 && ways >= 0
                    && Math.abs(score - bestScore) <= ROOM_WEIGHT
                    && ways < bestWays) {
                    // Within a room's worth, and easier to shut. This
                    // is the whole of what the count decides.
                    better = true;
                }
                if (better) {
                    best = building;
                    bestDef = def;
                    bestScore = score;
                    bestWays = ways;
                }
            }
            if (best == null) {
                return "";
            }
            int cx = bestDef.getX() + bestDef.getW() / 2;
            int cy = bestDef.getY() + bestDef.getH() / 2;
            boolean water = false;
            try {
                water = best.hasWater();
            } catch (Throwable ignored) {
            }
            return bestDef.getX() + ":" + bestDef.getY() + ":"
                + bestDef.getW() + ":" + bestDef.getH() + ":"
                + cx + ":" + cy + ":"
                + bestDef.getRoomsNumber() + ":" + bestDef.getArea() + ":"
                + (water ? 1 : 0) + ":"
                + String.format(java.util.Locale.ROOT, "%.1f", bestScore) + ":"
                + (bestWays < 0 ? waysIn(cell, bestDef) : bestWays);
        } catch (Throwable throwable) {
            return "";
        }
    }
}
