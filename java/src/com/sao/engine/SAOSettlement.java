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
 */
public final class SAOSettlement {

    private static final int MIN_ROOMS = 4;
    private static final int MIN_AREA = 48;

    private SAOSettlement() {
    }

    /**
     * Best candidate near the scout: "bx:by:bw:bh:cx:cy:rooms:area:water:score"
     * or "". rejectedCsv holds "x,y" building keys to skip.
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
                double score = rooms * 8.0
                    + Math.min(area, 240) * 0.15
                    + (water ? 15.0 : 0.0)
                    - dist * 0.05;
                if (score > bestScore) {
                    best = building;
                    bestDef = def;
                    bestScore = score;
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
                + String.format(java.util.Locale.ROOT, "%.1f", bestScore);
        } catch (Throwable throwable) {
            return "";
        }
    }
}
