package com.sao.engine;

import java.util.HashSet;
import java.util.Set;
import zombie.characters.IsoPlayer;
import zombie.characters.animals.IsoAnimal;
import zombie.iso.IsoCell;
import zombie.iso.IsoMovingObject;
import zombie.iso.areas.DesignationZoneAnimal;
import zombie.iso.objects.IsoFeedingTrough;
import zombie.iso.objects.IsoHutch;
import zombie.inventory.InventoryItem;

/**
 * [C123] The animal seam. Lua may decide which ordinary ranch task matters,
 * but this class reads the engine's designated ranch lists and returns only
 * compact facts or opaque objects for the engine's timed actions. Animals are
 * never person records, and nothing here creates food, water, stock, or a
 * mount.
 */
public final class SAOAnimals {

    private SAOAnimals() {
    }

    /**
     * Nearby designated-ranch animals, separated by {@code |}. Each record is
     * {@code type@id@x@y@z@hunger@thirst@stress@acceptance@zoneAcceptance@
     * milk@shear@eggs@troughWater@troughMax@handFeed@wild@baby@hutchs}.
     */
    public static String near(IsoPlayer shell, int radius) {
        try {
            StringBuilder answer = new StringBuilder();
            for (IsoAnimal animal : ranchAnimalsNear(shell, radius)) {
                DesignationZoneAnimal zone = ranchOf(animal);
                if (zone == null) {
                    continue;
                }
                float[] water = troughWater(zone);
                int eggs = animal.canHaveEggs() ? eggCount(zone) : 0;
                if (answer.length() > 0) {
                    answer.append('|');
                }
                answer.append(clean(animal.getAnimalType())).append('@')
                    .append(animal.getAnimalID()).append('@')
                    .append(animal.getX()).append('@')
                    .append(animal.getY()).append('@')
                    .append(animal.getZ()).append('@')
                    .append(animal.getHunger()).append('@')
                    .append(animal.getThirst()).append('@')
                    .append(animal.getStress()).append('@')
                    .append(animal.getAcceptanceLevel(shell)).append('@')
                    .append(animal.getZoneAcceptance()).append('@')
                    .append(animal.canBeMilked() && animal.readyToBeMilked()
                        ? 1 : 0).append('@')
                    .append(animal.canBeSheared() && animal.readyToBeSheared()
                        ? 1 : 0).append('@')
                    .append(eggs).append('@')
                    .append(water[0]).append('@').append(water[1]).append('@')
                    .append(animal.canBeFeedByHand() ? 1 : 0).append('@')
                    .append(animal.isWild() ? 1 : 0).append('@')
                    .append(animal.isBaby() ? 1 : 0).append('@')
                    .append(zone.getHutchs().size());
            }
            return answer.toString();
        } catch (Throwable ignored) {
            return "";
        }
    }

    /** The actual nearby ranch animal for a timed-action constructor. */
    public static Object target(IsoPlayer shell, int id, int radius) {
        for (IsoAnimal animal : ranchAnimalsNear(shell, radius)) {
            if (animal.getAnimalID() == id) {
                return animal;
            }
        }
        return null;
    }

    /** A ranch trough within action reach of the shell, or null. */
    public static Object trough(IsoPlayer shell, int id, int radius) {
        IsoAnimal animal = animalById(shell, id, radius);
        DesignationZoneAnimal zone = animal == null ? null : ranchOf(animal);
        if (zone == null) {
            return null;
        }
        IsoFeedingTrough nearest = null;
        float best = radius * radius;
        for (IsoFeedingTrough candidate : zone.getTroughs()) {
            if (candidate == null) {
                continue;
            }
            float dx = candidate.getX() - shell.getX();
            float dy = candidate.getY() - shell.getY();
            float distance = dx * dx + dy * dy;
            if (distance <= best) {
                best = distance;
                nearest = candidate;
            }
        }
        return nearest;
    }

    /** The hutch holding an egg from the selected animal's designated ranch. */
    public static Object hutchWithEgg(IsoPlayer shell, int id, int radius) {
        IsoAnimal animal = animalById(shell, id, radius);
        DesignationZoneAnimal zone = animal == null ? null : ranchOf(animal);
        if (zone == null) {
            return null;
        }
        for (IsoHutch hutch : zone.getHutchs()) {
            if (hutch != null && firstEggBox(hutch) != null) {
                return hutch;
            }
        }
        return null;
    }

    /** The hutch nest box with an actual egg, or null. */
    public static Object nestBoxWithEgg(IsoPlayer shell, int id, int radius) {
        IsoAnimal animal = animalById(shell, id, radius);
        DesignationZoneAnimal zone = animal == null ? null : ranchOf(animal);
        if (zone == null) {
            return null;
        }
        for (IsoHutch hutch : zone.getHutchs()) {
            IsoHutch.NestBox box = hutch == null ? null : firstEggBox(hutch);
            if (box != null) {
                return box;
            }
        }
        return null;
    }

    /**
     * An item the animal's own lure list accepts for hand feeding. No local
     * food vocabulary is maintained here.
     */
    public static Object handFeed(IsoPlayer shell, int id, int radius) {
        IsoAnimal animal = animalById(shell, id, radius);
        if (animal == null || !animal.canBeFeedByHand()) {
            return null;
        }
        var options = animal.getPossibleLuringItems(shell);
        return options == null || options.isEmpty() ? null : options.get(0);
    }

    /** A real carried drink is the only candidate to give a ranch trough. */
    public static Object carriedWater(IsoPlayer shell) {
        return SAONeeds.bestCarriedDrink(shell);
    }

    private static IsoAnimal animalById(IsoPlayer shell, int id, int radius) {
        Object target = target(shell, id, radius);
        return target instanceof IsoAnimal animal ? animal : null;
    }

    private static Set<IsoAnimal> ranchAnimalsNear(IsoPlayer shell,
                                                     int radius) {
        Set<IsoAnimal> answer = new HashSet<>();
        if (shell == null || radius < 0) {
            return answer;
        }
        IsoCell cell = shell.getCell();
        if (cell == null) {
            return answer;
        }
        float maximum = radius * radius;
        for (IsoMovingObject moving : cell.getObjectList()) {
            if (!(moving instanceof IsoAnimal observed) || observed.isDead()) {
                continue;
            }
            DesignationZoneAnimal zone = ranchOf(observed);
            if (zone == null) {
                continue;
            }
            for (IsoAnimal animal : zone.getAnimals()) {
                if (animal == null || animal.isDead()) {
                    continue;
                }
                float dx = animal.getX() - shell.getX();
                float dy = animal.getY() - shell.getY();
                if (dx * dx + dy * dy <= maximum) {
                    answer.add(animal);
                }
            }
        }
        return answer;
    }

    private static DesignationZoneAnimal ranchOf(IsoAnimal animal) {
        return animal == null ? null : DesignationZoneAnimal.getZone(
            (int) Math.floor(animal.getX()), (int) Math.floor(animal.getY()),
            (int) Math.floor(animal.getZ()));
    }

    private static float[] troughWater(DesignationZoneAnimal zone) {
        float water = 0.0f;
        float maximum = 0.0f;
        for (IsoFeedingTrough trough : zone.getTroughs()) {
            if (trough != null) {
                water += Math.max(0.0f, trough.getWater());
                maximum += Math.max(0.0f, trough.getMaxWater());
            }
        }
        return new float[] { water, maximum };
    }

    private static int eggCount(DesignationZoneAnimal zone) {
        int eggs = 0;
        for (IsoHutch hutch : zone.getHutchs()) {
            if (hutch == null) {
                continue;
            }
            for (int index = 0; index < hutch.getMaxNestBox(); index++) {
                IsoHutch.NestBox box = hutch.getNestBox(index);
                if (box != null) {
                    eggs += Math.max(0, box.getEggsNb());
                }
            }
        }
        return eggs;
    }

    private static IsoHutch.NestBox firstEggBox(IsoHutch hutch) {
        for (int index = 0; index < hutch.getMaxNestBox(); index++) {
            IsoHutch.NestBox box = hutch.getNestBox(index);
            if (box != null && box.getEggsNb() > 0) {
                return box;
            }
        }
        return null;
    }

    private static String clean(String value) {
        return value == null ? "animal" : value.replace('@', '_')
            .replace('|', '_');
    }
}