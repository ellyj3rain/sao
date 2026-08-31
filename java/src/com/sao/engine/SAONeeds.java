package com.sao.engine;

import com.sao.agent.SAOAgent;
import java.util.Map;
import java.util.WeakHashMap;

import zombie.characters.CharacterStat;
import zombie.characters.IsoPlayer;
import zombie.inventory.InventoryItem;
import zombie.inventory.ItemContainer;
import zombie.inventory.types.Food;
import zombie.iso.IsoCell;
import zombie.iso.IsoGridSquare;
import zombie.iso.IsoObject;

/**
 * The need side of the body: reads the engine's own stats, finds food the
 * survivor carries or the world holds nearby, and remembers a chosen source
 * so Lua can queue the vanilla actions against the exact objects chosen here.
 *
 * ENGINE LAW (ENGINE_CONTRACT §interop): engine collections and fields are
 * iterated HERE. Lua receives verdict strings, or opaque objects it passes
 * straight into vanilla action constructors without ever indexing them.
 */
public final class SAONeeds {

    /** A remembered world food source: the container and the item within it. */
    static final class FoodSource {
        ItemContainer container;
        InventoryItem item;
        int x, y, z;
    }

    private static final Map<IsoPlayer, FoodSource> SOURCES = new WeakHashMap<>();

    /** Scans look one floor up and down; the detour penalty keeps any
     * same-floor find preferred inside the radius. */
    private static final int[] FLOOR_RING = {0, -1, 1};
    private static final float CROSS_FLOOR_PENALTY = 4096.0f;

    private SAONeeds() {
    }

    /** Compact needs read: "h=<hunger>|t=<thirst>|f=<fatigue>|e=<endurance>". */
    public static String read(IsoPlayer shell) {
        try {
            zombie.characters.Stats stats = shell.getStats();
            // F-041: Locale.ROOT - the needs string is PARSED by Lua;
            // a comma-decimal locale would kill the whole appetite
            // machinery silently.
            return String.format(java.util.Locale.ROOT,
                "h=%.3f|t=%.3f|f=%.3f|e=%.3f|n=%.3f",
                stats.get(CharacterStat.HUNGER),
                stats.get(CharacterStat.THIRST),
                stats.get(CharacterStat.FATIGUE),
                stats.get(CharacterStat.ENDURANCE),
                stats.get(CharacterStat.NICOTINE_WITHDRAWAL));
        } catch (Throwable throwable) {
            return "";
        }
    }

    /** True when this food is worth a survivor's stomach. */
    private static boolean edible(InventoryItem item) {
        if (!(item instanceof Food food)) {
            return false;
        }
        if (food.isRotten() || food.getPoisonPower() > 0) {
            return false;
        }
        return food.getHungChange() < 0.0f;
    }

    /**
     * Best food the shell already carries, or null. The most filling piece
     * wins; a person eats their biggest meal first when hungry.
     */
    public static InventoryItem bestCarriedFood(IsoPlayer shell) {
        try {
            InventoryItem best = null;
            float bestFill = 0.0f;
            java.util.ArrayList<InventoryItem> items = shell.getInventory().getItems();
            for (int i = 0; i < items.size(); i++) {
                InventoryItem item = items.get(i);
                if (edible(item)) {
                    float fill = -((Food) item).getHungChange();
                    if (fill > bestFill) {
                        bestFill = fill;
                        best = item;
                    }
                }
            }
            return best;
        } catch (Throwable throwable) {
            return null;
        }
    }

    /**
     * Scan loaded squares around the shell for a container holding edible
     * food; remember the nearest hit and return "x:y:z:<display name>", or
     * "" when the loaded world nearby holds nothing. Looks one floor up and
     * down (stairs walk since [A9]); cross-floor finds carry a heavy
     * distance penalty so the detour happens only when this floor is bare.
     */
    public static String findFoodSourceNear(IsoPlayer shell, int radius) {
        try {
            // [B31] The last of [B31]'s four sweeps that was
            // genuinely drift. This differed from the shared one only
            // in the ORDER of two independent guards - it looked the
            // square up before asking whether the distance could win.
            // Outcome-identical either way, since the probe runs iff
            // both hold and neither condition touches the other; but
            // the shared form skips the cell lookup entirely when the
            // distance already cannot beat the best, which is strictly
            // less work across a radius cubed by the floor ring.
            FoodSource best = nearestOnFloorRing(shell, radius,
                square -> firstFoodIn(square));
            if (best == null) {
                SOURCES.remove(shell);
                return "";
            }
            SOURCES.put(shell, best);
            String name;
            try {
                name = best.item.getDisplayName();
            } catch (Throwable throwable) {
                name = "food";
            }
            return best.x + ":" + best.y + ":" + best.z + ":" + name;
        } catch (Throwable throwable) {
            return "";
        }
    }

    /** Nearest real container object within `radius` tiles of the shell,
     * same floor ([A19] quartermaster deposit target), else null. */
    /**
     * [A28] The pockets of the place: move up to max items matching a
     * WANT from the real containers around the shell into its
     * inventory. Wants are engine-truth tests (instanceof / category /
     * isWaterSource), never name tables. Returns how many were taken -
     * barren surroundings honestly yield poor pockets.
     */
    public static int takeWantedFromNearby(IsoPlayer shell, int radius,
            String want, int max) {
        int taken = 0;
        try {
            IsoCell cell = shell.getCell();
            int cx = (int) shell.getX(), cy = (int) shell.getY();
            int cz = (int) shell.getZ();
            for (int dx = -radius; dx <= radius && taken < max; dx++) {
                for (int dy = -radius; dy <= radius && taken < max; dy++) {
                    IsoGridSquare sq = cell.getGridSquare(cx + dx, cy + dy, cz);
                    if (sq == null) continue;
                    for (int i = 0; i < sq.getObjects().size()
                            && taken < max; i++) {
                        IsoObject obj = sq.getObjects().get(i);
                        ItemContainer c = obj.getContainer();
                        if (c == null) continue;
                        java.util.ArrayList<InventoryItem> items =
                            new java.util.ArrayList<>(c.getItems());
                        for (InventoryItem item : items) {
                            if (taken >= max) break;
                            if (wants(item, want)) {
                                c.Remove(item);
                                shell.getInventory().AddItem(item);
                                taken++;
                            }
                        }
                    }
                }
            }
        } catch (Throwable throwable) {
            SAOAgent.log("takeWantedFromNearby threw: " + throwable);
        }
        return taken;
    }

    /** [B9] The state a person is in when they meet someone: the
     *  engine's own social chemistry. "i=..|p=..|s=..|a=..|m=.."
     *  (intoxication, pain, stress+panic, anger, morale).
     *  F-041: Locale.ROOT - this string is PARSED by Lua. */
    public static String socialState(IsoPlayer shell) {
        try {
            zombie.characters.Stats stats = shell.getStats();
            float stress = stats.get(CharacterStat.STRESS)
                + stats.get(CharacterStat.PANIC);
            return String.format(java.util.Locale.ROOT,
                "i=%.3f|p=%.3f|s=%.3f|a=%.3f|m=%.3f",
                stats.get(CharacterStat.INTOXICATION),
                stats.get(CharacterStat.PAIN),
                Math.min(1.0f, stress),
                stats.get(CharacterStat.ANGER),
                stats.get(CharacterStat.MORALE));
        } catch (Throwable throwable) {
            return "";
        }
    }

    /** [B7] How bad the wounds have gone: the engine's own general
     *  wound-infection level (0 when clean). */
    public static float woundInfection(IsoPlayer shell) {
        try {
            if (shell.getBodyDamage() != null) {
                return shell.getBodyDamage().getGeneralWoundInfectionLevel();
            }
        } catch (Throwable ignored) {
        }
        return 0.0f;
    }

    /** [B7] How many dressings have gone dirty on this body. */
    public static int dirtyBandages(IsoPlayer shell) {
        int count = 0;
        try {
            zombie.characters.BodyDamage.BodyDamage damage =
                shell.getBodyDamage();
            if (damage == null) return 0;
            for (zombie.characters.BodyDamage.BodyPartType type
                    : zombie.characters.BodyDamage.BodyPartType.values()) {
                zombie.characters.BodyDamage.BodyPart part =
                    damage.getBodyPart(type);
                if (part != null && part.bandaged() && part.isBandageDirty()) {
                    count++;
                }
            }
        } catch (Throwable ignored) {
        }
        return count;
    }

    /** [B7] Clean a wound with what is really carried: any item whose
     *  own alcohol content the engine reports. Returns the part
     *  cleaned, or "". The item is consumed. */
    public static String disinfectFromPack(IsoPlayer shell) {
        try {
            zombie.characters.BodyDamage.BodyDamage damage =
                shell.getBodyDamage();
            if (damage == null) return "";
            zombie.characters.BodyDamage.BodyPart worst = null;
            String worstName = "";
            float worstLevel = 0.0f;
            for (zombie.characters.BodyDamage.BodyPartType type
                    : zombie.characters.BodyDamage.BodyPartType.values()) {
                zombie.characters.BodyDamage.BodyPart part =
                    damage.getBodyPart(type);
                if (part == null) continue;
                float level = part.getWoundInfectionLevel();
                if (level > worstLevel && part.getAlcoholLevel() < 1.0f) {
                    worst = part;
                    worstName = type.toString();
                    worstLevel = level;
                }
            }
            if (worst == null) return "";
            InventoryItem cleaner = null;
            java.util.ArrayList<InventoryItem> items =
                shell.getInventory().getItems();
            for (int i = 0; i < items.size(); i++) {
                InventoryItem item = items.get(i);
                if (item.getAlcoholPower() > 0.0f) {
                    cleaner = item;
                    break;
                }
            }
            if (cleaner == null) return "";
            worst.setAlcoholLevel(
                Math.min(5.0f, worst.getAlcoholLevel()
                    + cleaner.getAlcoholPower()));
            shell.getInventory().Remove(cleaner);
            return worstName;
        } catch (Throwable throwable) {
            SAOAgent.log("disinfectFromPack threw: " + throwable);
        }
        return "";
    }

    /** [B7, corrected in B7] How cold this shell actually is: the
     *  deficit of real CORE TEMPERATURE below healthy (37C), read
     *  from the engine's own thermoregulator. 0 when warm; ~1 is
     *  chilled; ~2 is dangerous.
     *
     *  The first implementation read `getColdStrength()`, which is
     *  the ILLNESS (it lives with catchACold, hasACold, and the
     *  sneeze timers) - the fires were answering sneezes. */
    public static float coldStrength(IsoPlayer shell) {
        try {
            zombie.characters.BodyDamage.BodyDamage damage =
                shell.getBodyDamage();
            if (damage != null && damage.getThermoregulator() != null) {
                float core = damage.getThermoregulator().getCoreTemperature();
                return Math.max(0.0f, 37.0f - core);
            }
        } catch (Throwable ignored) {
        }
        return 0.0f;
    }

    /** [B7] The illness the correction uncovered: how badly this
     *  body has caught a cold (the engine's own progression). */
    public static float sickness(IsoPlayer shell) {
        try {
            if (shell.getBodyDamage() != null) {
                return shell.getBodyDamage().getColdStrength();
            }
        } catch (Throwable ignored) {
        }
        return 0.0f;
    }

    /** [B6] The nearest hearth with fuel in it, as "x:y:z:fuel", or
     *  "" when the ground offers none. Pure read. */
    /** [B31] The nearest hearth, found ONCE.
     *
     *  Three methods each carried their own copy of this search -
     *  identical loops, identical instanceof, identical
     *  first-hit-wins - and differed only in what they did with the
     *  fire they found. Change the radius rule or teach it to prefer
     *  a lit hearth and two of the three would have kept the old
     *  behaviour, with nothing raised anywhere. That is [B24]'s shape
     *  in slow motion, and it is why this codebase writes one
     *  definition and calls it twice ([B20], [B27], [B28]).
     *
     *  Returns null when there is no fire in range. */
    private static zombie.iso.objects.IsoFireplace findHearth(
            IsoPlayer shell, int radius) {
        IsoCell cell = shell.getCell();
        if (cell == null) return null;
        int cx = (int) shell.getX(), cy = (int) shell.getY();
        int cz = (int) shell.getZ();
        for (int dy = -radius; dy <= radius; dy++) {
            for (int dx = -radius; dx <= radius; dx++) {
                IsoGridSquare sq = cell.getGridSquare(cx + dx, cy + dy, cz);
                if (sq == null) continue;
                java.util.List<IsoObject> objects = sq.getObjects();
                for (int i = 0; i < objects.size(); i++) {
                    if (objects.get(i)
                            instanceof zombie.iso.objects.IsoFireplace f) {
                        return f;
                    }
                }
            }
        }
        return null;
    }

    public static String hearthNear(IsoPlayer shell, int radius) {
        try {
            // [B31] Same search as the other two, so the same
            // definition. The square comes off the object rather than
            // being carried out of the loop.
            zombie.iso.objects.IsoFireplace fire = findHearth(shell, radius);
            if (fire != null) {
                IsoGridSquare sq = fire.getSquare();
                if (sq != null) {
                    return sq.getX() + ":" + sq.getY() + ":"
                        + sq.getZ() + ":" + fire.getFuelAmount()
                        + ":" + (fire.isLit() ? 1 : 0);
                }
            }
        } catch (Throwable throwable) {
            SAOAgent.log("hearthNear threw: " + throwable);
        }
        return "";
    }

    /** [B6] Light a fuelled but dead hearth - only with the MEANS
     *  actually carried (a lighter or matches; the task names its
     *  object). Returns true when a fire was started. */
    public static boolean lightNearbyHearth(IsoPlayer shell, int radius) {
        try {
            zombie.iso.objects.IsoFireplace hearth =
                findHearth(shell, radius);
            if (hearth == null || hearth.isLit() || !hearth.hasFuel()) {
                return false;
            }
            boolean means = false;
            java.util.ArrayList<InventoryItem> items =
                shell.getInventory().getItems();
            for (int i = 0; i < items.size(); i++) {
                String full = items.get(i).getFullType();
                if (full != null
                    && (full.contains("Lighter") || full.contains("Matches"))) {
                    means = true;
                    break;
                }
            }
            if (!means) return false;
            hearth.setLit(true);
            return true;
        } catch (Throwable throwable) {
            SAOAgent.log("lightNearbyHearth threw: " + throwable);
        }
        return false;
    }

    /** [B6] Feed the nearest hearth what the shell carries that
     *  actually burns (getMinutesToBurn is the engine's own test).
     *  The item is consumed; returns fuel units added. */
    public static int feedNearbyHearth(IsoPlayer shell, int radius) {
        try {
            zombie.iso.objects.IsoFireplace hearth =
                findHearth(shell, radius);
            if (hearth == null) return 0;
            java.util.ArrayList<InventoryItem> items =
                shell.getInventory().getItems();
            InventoryItem best = null;
            float bestBurn = 0.0f;
            for (int i = 0; i < items.size(); i++) {
                InventoryItem item = items.get(i);
                if (item.isEquipped()) continue;
                float burn = item.getMinutesToBurn();
                if (burn > bestBurn) {
                    best = item;
                    bestBurn = burn;
                }
            }
            if (best == null || bestBurn <= 0.0f) return 0;
            int units = Math.max(1, Math.round(bestBurn / 30.0f));
            hearth.addFuel(units);
            shell.getInventory().Remove(best);
            return units;
        } catch (Throwable throwable) {
            SAOAgent.log("feedNearbyHearth threw: " + throwable);
        }
        return 0;
    }

    /** [B6] Fill carried vessels from a real clean water source
     *  within radius: the source is drained by exactly what the
     *  vessels take. Returns units moved (0 when the world offers
     *  nothing or the shell carries nothing to fill). */
    public static float fillWaterFromNearby(IsoPlayer shell, int radius) {
        float moved = 0.0f;
        try {
            IsoCell cell = shell.getCell();
            if (cell == null) return 0.0f;
            int cx = (int) shell.getX(), cy = (int) shell.getY();
            int cz = (int) shell.getZ();
            IsoObject source = null;
            outer:
            for (int dy = -radius; dy <= radius; dy++) {
                for (int dx = -radius; dx <= radius; dx++) {
                    IsoGridSquare square = cell.getGridSquare(cx + dx, cy + dy, cz);
                    if (square == null) continue;
                    java.util.List<IsoObject> objects = square.getObjects();
                    for (int i = 0; i < objects.size(); i++) {
                        IsoObject object = objects.get(i);
                        if (object.hasFluid() && object.getFluidAmount() > 0.1f
                            && !object.isTaintedWater()) {
                            source = object;
                            break outer;
                        }
                    }
                }
            }
            if (source == null) return 0.0f;
            java.util.ArrayList<InventoryItem> items =
                shell.getInventory().getItems();
            for (int i = 0; i < items.size(); i++) {
                InventoryItem item = items.get(i);
                zombie.entity.components.fluids.FluidContainer vessel =
                    item.getFluidContainerFromSelfOrWorldItem();
                if (vessel == null) continue;
                float free = vessel.getFreeCapacity();
                if (free <= 0.01f) continue;
                float have = source.getFluidAmount();
                if (have <= 0.1f) break;
                float take = Math.min(free, have);
                source.useFluid(take);
                vessel.addFluid(
                    zombie.entity.components.fluids.Fluid.Water, take);
                moved += take;
            }
        } catch (Throwable throwable) {
            SAOAgent.log("fillWaterFromNearby threw: " + throwable);
        }
        return moved;
    }

    /** [B6] READ the stored water: units held in vessels inside the
     *  real containers around the shell. Pure read. */
    public static float countStoredWaterNearby(IsoPlayer shell, int radius) {
        float total = 0.0f;
        try {
            IsoCell cell = shell.getCell();
            int cx = (int) shell.getX(), cy = (int) shell.getY();
            int cz = (int) shell.getZ();
            for (int dx = -radius; dx <= radius; dx++) {
                for (int dy = -radius; dy <= radius; dy++) {
                    IsoGridSquare sq = cell.getGridSquare(cx + dx, cy + dy, cz);
                    if (sq == null) continue;
                    for (int i = 0; i < sq.getObjects().size(); i++) {
                        ItemContainer c = sq.getObjects().get(i).getContainer();
                        if (c == null) continue;
                        java.util.ArrayList<InventoryItem> items = c.getItems();
                        for (int j = 0; j < items.size(); j++) {
                            zombie.entity.components.fluids.FluidContainer v =
                                items.get(j)
                                    .getFluidContainerFromSelfOrWorldItem();
                            if (v != null) total += v.getAmount();
                        }
                    }
                }
            }
        } catch (Throwable throwable) {
            SAOAgent.log("countStoredWaterNearby threw: " + throwable);
        }
        return total;
    }

    /** [B6] The county's mains: true while the taps still run. */
    public static boolean countyWaterOn() {
        try {
            return zombie.iso.IsoWorld.instance.isHydroPowerOn();
        } catch (Throwable throwable) {
            return true;
        }
    }

    /** [B1] Seat a shell into the nearest vehicle to (px,py) with a
     *  free non-driver seat, via the engine's own enter contract.
     *  Returns the seat index or -1. */
    public static int seatInNearestVehicle(IsoPlayer shell,
            float px, float py) {
        try {
            IsoCell cell = shell.getCell();
            zombie.vehicles.BaseVehicle best = null;
            float bestD = 5 * 5;
            for (zombie.vehicles.BaseVehicle vehicle : cell.getVehicles()) {
                if (vehicle == null) continue;
                float dx = vehicle.getX() - px, dy = vehicle.getY() - py;
                float d = dx * dx + dy * dy;
                if (d < bestD) { best = vehicle; bestD = d; }
            }
            if (best == null) return -1;
            int seats = best.getMaxPassengers();
            for (int i = 1; i < seats; i++) {
                if (!best.isSeatOccupied(i)) {
                    if (best.enter(i, shell)) return i;
                }
            }
        } catch (Throwable throwable) {
            SAOAgent.log("seatInNearestVehicle threw: " + throwable);
        }
        return -1;
    }

    /** [B1] Release a seated shell through the engine's exit. */
    public static boolean unseatFromVehicle(IsoPlayer shell) {
        try {
            zombie.vehicles.BaseVehicle vehicle = shell.getVehicle();
            if (vehicle != null) {
                return vehicle.exit(shell);
            }
        } catch (Throwable throwable) {
            SAOAgent.log("unseatFromVehicle threw: " + throwable);
        }
        return false;
    }

    /** [B19] APPRAISE the motor pool. Not "how many cars are
     *  parked here" - which the county was reading as wealth while
     *  standing in a yard of hulks - but "what can we actually
     *  drive". Every field is READ off the real vehicle; none of it
     *  is authored. Engine loudness in particular is a per-script
     *  number the game already ships, so the operator's low-key
     *  sedan versus loud wagon is a fact to read, not a table to
     *  write.
     *
     *  Serialized name@seats@free@fuel@engine@loud@storage@
     *  ignition@hotwired@dist, comma-joined. Empty when no cars
     *  exist, which is a fact too.
     *
     *  VERIFIED against this build (B42.20.4) with javap:
     *  getKeyId() and getBatteryCharge() are NOT on this
     *  BaseVehicle, even though the vanilla Lua shipped in the same
     *  install calls both. Nothing here depends on them. */
    /** [B31] The name the motor pool knows a car by.
     *
     *  appraiseVehiclesNear writes this into an @-delimited record and
     *  spendVehicleFuel has to find the car again by it, so both must
     *  spell it the same way. Written once rather than twice: a spend
     *  matching raw getScriptName() would agree only for names that
     *  happen to need no sanitising, and would silently never fire for
     *  exactly the names the sanitiser exists for. */
    private static String poolName(zombie.vehicles.BaseVehicle vehicle) {
        if (vehicle == null) return "vehicle";
        String name = vehicle.getScriptName();
        if (name == null) name = "vehicle";
        return name.replace(",", " ").replace("@", " ");
    }

    /** [B31] The fuel tank of a vehicle, found the way the engine
     *  finds it.
     *
     *  BaseVehicle.getRemainingFuelPercentage() resolves the part by
     *  the id "GasTank" and divides its content amount by its
     *  capacity - so this is the engine's own identifier for the
     *  thing, not a plausible-looking guess ([B26]'s lesson). It is
     *  declared as `part GasTank` in 122 shipped vehicle scripts.
     *
     *  getPartById is inherited and not reachable from here, so the
     *  parts are walked and matched on the public getId(). */
    private static zombie.vehicles.VehiclePart gasTankOf(
            zombie.vehicles.BaseVehicle vehicle) {
        if (vehicle == null) return null;
        zombie.vehicles.VehicleParts parts = vehicle.getParts();
        if (parts == null) return null;
        for (int i = 0; i < parts.size(); i++) {
            zombie.vehicles.VehiclePart part = parts.get(i);
            if (part != null && "GasTank".equals(part.getId())) {
                return part;
            }
        }
        return null;
    }

    /** [B31] Spend fuel from the named vehicle near this shell, as a
     *  percentage of its tank. Returns the percentage actually
     *  burned, which is less than asked for when the tank runs dry.
     *
     *  `roadworthy` gated on fuel and nothing ever spent it, so a car
     *  at 6% carried doubled-range ventures forever. Everywhere else
     *  in this mod, acting on real state changes it.
     *
     *  The percentage is converted through the tank's own capacity
     *  because that is exactly how the engine converts it back:
     *  percentage = amount / capacity * 100. */
    public static float spendVehicleFuel(IsoPlayer shell, int radius,
            String name, float percent) {
        if (shell == null || name == null || percent <= 0.0f) return 0.0f;
        try {
            IsoCell cell = shell.getCell();
            if (cell == null) return 0.0f;
            float sx = shell.getX(), sy = shell.getY();
            zombie.vehicles.BaseVehicle found = null;
            float bestD2 = (float) radius * radius;
            for (zombie.vehicles.BaseVehicle vehicle : cell.getVehicles()) {
                if (vehicle == null) continue;
                if (!name.equals(poolName(vehicle))) continue;
                float dx = vehicle.getX() - sx, dy = vehicle.getY() - sy;
                float d2 = dx * dx + dy * dy;
                if (d2 <= bestD2) {
                    bestD2 = d2;
                    found = vehicle;
                }
            }
            zombie.vehicles.VehiclePart tank = gasTankOf(found);
            if (tank == null) return 0.0f;
            int capacity = tank.getContainerCapacity();
            if (capacity <= 0) return 0.0f;
            float have = tank.getContainerContentAmount();
            float want = capacity * (percent / 100.0f);
            float burn = Math.min(have, want);
            if (burn <= 0.0f) return 0.0f;
            tank.setContainerContentAmount(have - burn);
            return burn / capacity * 100.0f;
        } catch (Throwable throwable) {
            SAOAgent.log("spendVehicleFuel threw: " + throwable);
        }
        return 0.0f;
    }

    public static String appraiseVehiclesNear(IsoPlayer shell, int radius) {
        StringBuilder out = new StringBuilder();
        try {
            IsoCell cell = shell.getCell();
            float sx = shell.getX(), sy = shell.getY();
            for (zombie.vehicles.BaseVehicle vehicle : cell.getVehicles()) {
                if (vehicle == null) continue;
                float dx = vehicle.getX() - sx, dy = vehicle.getY() - sy;
                float d2 = dx * dx + dy * dy;
                if (d2 > (float) radius * radius) continue;
                int seats = vehicle.getMaxPassengers();
                int free = 0;
                for (int i = 0; i < seats; i++) {
                    if (!vehicle.isSeatOccupied(i)) free++;
                }
                int fuel = 0, engine = 0, loud = 0, storage = 0;
                try {
                    fuel = (int) vehicle.getRemainingFuelPercentage();
                } catch (Throwable ignored) { }
                try {
                    engine = vehicle.getEngineCondition();
                } catch (Throwable ignored) { }
                try {
                    zombie.scripting.objects.VehicleScript script =
                        vehicle.getScript();
                    if (script != null) {
                        loud = script.getEngineLoudness();
                        storage = script.getStorageCapacity();
                    }
                } catch (Throwable ignored) { }
                int ignition = 0;
                try {
                    if (vehicle.isKeysInIgnition()
                        || vehicle.getCurrentKey() != null) {
                        ignition = 1;
                    }
                } catch (Throwable ignored) { }
                int hot = 0;
                try {
                    if (vehicle.isHotwired()) hot = 1;
                } catch (Throwable ignored) { }
                if (out.length() > 0) out.append(",");
                out.append(poolName(vehicle))
                   .append("@").append(Math.max(0, seats))
                   .append("@").append(Math.max(0, free))
                   .append("@").append(Math.max(0, fuel))
                   .append("@").append(Math.max(0, engine))
                   .append("@").append(Math.max(0, loud))
                   .append("@").append(Math.max(0, storage))
                   .append("@").append(ignition)
                   .append("@").append(hot)
                   .append("@").append((int) Math.sqrt(d2));
            }
        } catch (Throwable throwable) {
            SAOAgent.log("appraiseVehiclesNear threw: " + throwable);
        }
        return out.toString();
    }

    /** [A28] READ the larder: count edible items in the real
     *  containers around the shell. Pure read - nothing moves. */
    public static int countEdibleNearby(IsoPlayer shell, int radius) {
        int count = 0;
        try {
            IsoCell cell = shell.getCell();
            int cx = (int) shell.getX(), cy = (int) shell.getY();
            int cz = (int) shell.getZ();
            for (int dx = -radius; dx <= radius; dx++) {
                for (int dy = -radius; dy <= radius; dy++) {
                    IsoGridSquare sq = cell.getGridSquare(cx + dx, cy + dy, cz);
                    if (sq == null) continue;
                    for (int i = 0; i < sq.getObjects().size(); i++) {
                        ItemContainer c = sq.getObjects().get(i).getContainer();
                        if (c == null) continue;
                        java.util.ArrayList<InventoryItem> items = c.getItems();
                        for (int j = 0; j < items.size(); j++) {
                            if (items.get(j) instanceof Food) count++;
                        }
                    }
                }
            }
        } catch (Throwable throwable) {
            SAOAgent.log("countEdibleNearby threw: " + throwable);
        }
        return count;
    }

    /** [B20] COOK the larder. Vanilla gates dangerous raw food on
     *  `isbDangerousUncooked() && !isCooked()` - so making it cooked
     *  is precisely what turns food nobody should eat into food they
     *  can. The house feels this: it is the cook's knowledge landing
     *  on somebody else's dinner.
     *
     *  Skill is throughput. A trained cook makes more of the larder
     *  safe in a session than a willing amateur - the count is a
     *  judgment on a real scale, the way the [B7] cold thresholds are
     *  judgments on real degrees. Returns how many were cooked. */
    public static int cookNearbyFood(IsoPlayer shell, int radius, int level) {
        int cooked = 0;
        int allowance = 2 + Math.max(0, level);
        try {
            IsoCell cell = shell.getCell();
            int cx = (int) shell.getX(), cy = (int) shell.getY();
            int cz = (int) shell.getZ();
            for (int dx = -radius; dx <= radius && cooked < allowance; dx++) {
                for (int dy = -radius; dy <= radius && cooked < allowance; dy++) {
                    IsoGridSquare sq = cell.getGridSquare(cx + dx, cy + dy, cz);
                    if (sq == null) continue;
                    for (int i = 0; i < sq.getObjects().size()
                        && cooked < allowance; i++) {
                        ItemContainer c = sq.getObjects().get(i).getContainer();
                        if (c == null) continue;
                        java.util.ArrayList<InventoryItem> items = c.getItems();
                        for (int j = 0; j < items.size()
                            && cooked < allowance; j++) {
                            InventoryItem item = items.get(j);
                            if (!(item instanceof Food food)) continue;
                            if (food.isCooked() || food.isBurnt()
                                || food.isRotten()) continue;
                            if (!food.isbDangerousUncooked()) continue;
                            food.cooked = true;
                            cooked++;
                        }
                    }
                }
            }
        } catch (Throwable throwable) {
            SAOAgent.log("cookNearbyFood threw: " + throwable);
        }
        return cooked;
    }

    /** [B21] What the music does to whoever is near enough to hear
     *  it. BOREDOM down, MORALE up - real engine stats, not a number
     *  this mod invented. Every living person in reach counts,
     *  including the player: they are in this society, not watching
     *  it.
     *
     *  There is no musicianship perk in vanilla and none is invented
     *  here, so the effect does not vary by who plays. What varies is
     *  whether anybody comes, which is a social question and is
     *  answered elsewhere. */
    public static int easeListeners(IsoPlayer shell, int radius) {
        int eased = 0;
        try {
            IsoCell cell = shell.getCell();
            float sx = shell.getX(), sy = shell.getY();
            for (int i = 0; i < IsoPlayer.players.length; i++) {
                IsoPlayer person = IsoPlayer.players[i];
                if (person == null || person == shell) continue;
                if (person.isDead()) continue;
                float dx = person.getX() - sx, dy = person.getY() - sy;
                if (dx * dx + dy * dy > (float) radius * radius) continue;
                person.getStats().add(
                    zombie.characters.CharacterStat.BOREDOM, -0.08f);
                person.getStats().add(
                    zombie.characters.CharacterStat.MORALE, 0.05f);
                eased++;
            }
            for (zombie.iso.IsoMovingObject moving : cell.getObjectList()) {
                if (!(moving instanceof IsoPlayer person)) continue;
                if (person == shell || person.isDead()) continue;
                boolean alreadyCounted = false;
                for (int i = 0; i < IsoPlayer.players.length; i++) {
                    if (IsoPlayer.players[i] == person) {
                        alreadyCounted = true;
                        break;
                    }
                }
                if (alreadyCounted) continue;
                float dx = person.getX() - sx, dy = person.getY() - sy;
                if (dx * dx + dy * dy > (float) radius * radius) continue;
                person.getStats().add(
                    zombie.characters.CharacterStat.BOREDOM, -0.08f);
                person.getStats().add(
                    zombie.characters.CharacterStat.MORALE, 0.05f);
                eased++;
            }
        } catch (Throwable throwable) {
            SAOAgent.log("easeListeners threw: " + throwable);
        }
        return eased;
    }

    /** [B21] What the cook has NOT done. The same vanilla gate
     *  [B20] cooks against - `isbDangerousUncooked() && !isCooked()` -
     *  read from the other side, so the work and the measure of the
     *  work are one fact rather than two opinions. Evidence lying
     *  around in plain sight, which is what "the house decides"
     *  means. */
    public static int countRawDangerNearby(IsoPlayer shell, int radius) {
        int raw = 0;
        try {
            IsoCell cell = shell.getCell();
            int cx = (int) shell.getX(), cy = (int) shell.getY();
            int cz = (int) shell.getZ();
            for (int dx = -radius; dx <= radius; dx++) {
                for (int dy = -radius; dy <= radius; dy++) {
                    IsoGridSquare sq = cell.getGridSquare(cx + dx, cy + dy, cz);
                    if (sq == null) continue;
                    for (int i = 0; i < sq.getObjects().size(); i++) {
                        ItemContainer c = sq.getObjects().get(i).getContainer();
                        if (c == null) continue;
                        java.util.ArrayList<InventoryItem> items = c.getItems();
                        for (int j = 0; j < items.size(); j++) {
                            InventoryItem item = items.get(j);
                            if (!(item instanceof Food food)) continue;
                            if (food.isRotten() || food.isBurnt()) continue;
                            if (food.isbDangerousUncooked() && !food.isCooked()) {
                                raw++;
                            }
                        }
                    }
                }
            }
        } catch (Throwable throwable) {
            SAOAgent.log("countRawDangerNearby threw: " + throwable);
        }
        return raw;
    }

    /** [B22] How bored someone is - the engine's own number, so
     *  "would this help them" is a question with a real answer
     *  instead of an assumption. */
    public static float boredom(IsoPlayer shell) {
        try {
            return shell.getStats().get(
                zombie.characters.CharacterStat.BOREDOM);
        } catch (Throwable throwable) {
            SAOAgent.log("boredom threw: " + throwable);
        }
        return 0.0f;
    }

    /** [B22] What a keepsake is worth: it steadies the person
     *  carrying it and does nothing whatever for the house. That is
     *  the point of one. */
    public static void steady(IsoPlayer shell, float morale) {
        try {
            shell.getStats().add(
                zombie.characters.CharacterStat.MORALE, morale);
        } catch (Throwable throwable) {
            SAOAgent.log("steady threw: " + throwable);
        }
    }

    /** [B22] Is this the book a given trade rides on, with reading
     *  left in it? Matched on the engine's own `getSkillTrained`, so
     *  a modded skill book announces itself exactly as a vanilla one
     *  does. */
    private static boolean teachesPerk(InventoryItem item, String perk) {
        if (perk == null) return false;
        if (!(item instanceof zombie.inventory.types.Literature book)) {
            return false;
        }
        String trains = book.getSkillTrained();
        if (trains == null || !trains.equalsIgnoreCase(perk)) return false;
        return book.getAlreadyReadPages() < book.getNumberOfPages();
    }

    /** [B22] Take the book this survivor's own trade rides on from a
     *  real container nearby. Nothing is granted; if the place does
     *  not hold it, they do not have it. */
    public static boolean takeSkillBookFor(IsoPlayer shell, int radius,
        String perk) {
        try {
            IsoCell cell = shell.getCell();
            int cx = (int) shell.getX(), cy = (int) shell.getY();
            int cz = (int) shell.getZ();
            for (int dx = -radius; dx <= radius; dx++) {
                for (int dy = -radius; dy <= radius; dy++) {
                    IsoGridSquare sq = cell.getGridSquare(cx + dx, cy + dy, cz);
                    if (sq == null) continue;
                    for (int i = 0; i < sq.getObjects().size(); i++) {
                        ItemContainer c = sq.getObjects().get(i).getContainer();
                        if (c == null) continue;
                        java.util.ArrayList<InventoryItem> items = c.getItems();
                        for (int j = 0; j < items.size(); j++) {
                            InventoryItem item = items.get(j);
                            if (!teachesPerk(item, perk)) continue;
                            c.Remove(item);
                            shell.getInventory().AddItem(item);
                            return true;
                        }
                    }
                }
            }
        } catch (Throwable throwable) {
            SAOAgent.log("takeSkillBookFor threw: " + throwable);
        }
        return false;
    }

    /** [B22] Read a page or so of the carried book for this trade,
     *  through the engine's own `ReadLiterature` - so the XP
     *  multiplier, the page count and the level ceiling are all the
     *  game's, not ours. Returns the trade read up on, or "". */
    public static String readSkillBook(IsoPlayer shell, String perk) {
        try {
            java.util.ArrayList<InventoryItem> carried =
                shell.getInventory().getItems();
            for (int i = 0; i < carried.size(); i++) {
                InventoryItem item = carried.get(i);
                if (!teachesPerk(item, perk)) continue;
                zombie.inventory.types.Literature book =
                    (zombie.inventory.types.Literature) item;
                shell.ReadLiterature(book);
                return book.getSkillTrained();
            }
        } catch (Throwable throwable) {
            SAOAgent.log("readSkillBook threw: " + throwable);
        }
        return "";
    }

    private static boolean wants(InventoryItem item, String want) {
        if (item == null || want == null) return false;
        switch (want) {
            case "weapon":
                return item instanceof zombie.inventory.types.HandWeapon;
            case "food":
                return item instanceof zombie.inventory.types.Food;
            case "water":
                return item.isWaterSource();
            case "medical":
                // [B26] This read getCategory(), which returns the
                // Java-class category - mainCategory, or "Item" when
                // unset - and never a script DisplayCategory. The
                // script Item class has no category field at all, and
                // the game's own Lua only ever compares getCategory()
                // to Container, Clothing, Key, Literature and
                // AlarmClock. So "FirstAid" could never match, and
                // all 53 first-aid items were unreachable: the carer
                // walked past every bandage in Knox County.
                return "FirstAid".equals(item.getDisplayCategory());
            case "device":
                return item instanceof zombie.inventory.types.Radio;
            case "tool":
                // [B26] The same dead read as `medical` above. 72
                // items sit in the Tool display category and the
                // trades could reach none of them.
                return "Tool".equals(item.getDisplayCategory());
            case "smokes":
                // The habit names its object - identity, not a table.
                // [B26] Except Base.Cigarettes DOES NOT EXIST in
                // B42.20.4 - the engine calls them CigarettePack,
                // CigaretteSingle, CigaretteCarton, CigaretteRolled -
                // so the only half of this that ever fired was the
                // matches. A smoker sought the light and never the
                // cigarette. SMOKABLE is the engine's own word for a
                // thing you smoke, which is what the habit is about;
                // the TOBACCO tag is deliberately NOT used, because
                // it reaches raw crop material and this is about what
                // the world already holds.
                return item.hasTag(
                        zombie.scripting.objects.ItemTag.SMOKABLE)
                    || "Base.Matches".equals(item.getFullType());
            case "instrument":
                return "InstrumentWeapon".equals(item.getDisplayCategory());
            case "memento":
                // [B22] The engine already has a word for a thing you
                // keep for what it means rather than what it does.
                // [B26] It has TWO, and we read one. DisplayCategory
                // is where a thing sits in the UI; the tag is the
                // engine's claim about what the thing IS. 231 items
                // carry the tag, 218 sit in the category, and 45 of
                // the tagged ones sat somewhere else entirely -
                // PhotoAlbum under Container, Harmonica under
                // Instrument, the rabbit's-foot keyring, the
                // expensive wristwatches. A photo album is the
                // archetype of the sentence above and could never be
                // one. The union can only add.
                return "Memento".equals(item.getDisplayCategory())
                    || item.hasTag(
                        zombie.scripting.objects.ItemTag.IS_MEMENTO);
            case "reading":
                return "Literature".equals(item.getDisplayCategory());
            case "plank":
                // The task names its object - identity, not a table.
                return "Base.Plank".equals(item.getFullType());
            case "nails":
                return "Base.Nails".equals(item.getFullType())
                    || "Base.NailsBox".equals(item.getFullType());
            case "fuel":
                // The engine names its own fuel ([B6]): anything with
                // burn minutes is firewood. No item table.
                return item.getMinutesToBurn() > 0.0f
                    && !item.isEquipped();
            case "light":
                // The engine names its own light ([B17]).
                return item.getLightStrength() > 0.0f;
            case "seeds":
                // The seed family names itself ([B4]).
                // [B26] It stopped naming itself that way. B21 names
                // seeds SINGULAR - CornSeed, FlaxSeed, WheatSeed,
                // BarleySeed - so this matched exactly one item in
                // the entire game, SunflowerSeeds, against 79 that
                // carry the engine's own IS_SEED tag. The farmer
                // could only ever spot sunflowers. The union keeps
                // the old shape rather than trusting one vocabulary
                // alone, which is [B26]'s lesson.
                return item.hasTag(
                        zombie.scripting.objects.ItemTag.IS_SEED)
                    || (item.getFullType() != null
                        && item.getFullType().endsWith("Seeds"));
            default:
                return false;
        }
    }

    /** [A28] Ownership is READ: first carried item of a display
     *  category, or empty - the claim derives from what the place
     *  actually yielded. */
    /** [B26] What they kept, by BOTH of the engine's words for it.
     *  The seek side and the read-back side have to agree, or a
     *  survivor picks up a photo album and the record still says they
     *  carry nothing - which is the [B24] shape wearing a new coat. */
    public static String carriedMemento(IsoPlayer shell) {
        try {
            java.util.ArrayList<InventoryItem> items =
                shell.getInventory().getItems();
            for (int i = 0; i < items.size(); i++) {
                InventoryItem item = items.get(i);
                if (item == null) continue;
                if ("Memento".equals(item.getDisplayCategory())
                        || item.hasTag(
                            zombie.scripting.objects.ItemTag.IS_MEMENTO)) {
                    return item.getFullType();
                }
            }
        } catch (Throwable throwable) {
            SAOAgent.log("carriedMemento threw: " + throwable);
        }
        return "";
    }

    public static String carriedDisplayCategory(IsoPlayer shell, String cat) {
        try {
            java.util.ArrayList<InventoryItem> items =
                shell.getInventory().getItems();
            for (int i = 0; i < items.size(); i++) {
                InventoryItem item = items.get(i);
                if (cat.equals(item.getDisplayCategory())) {
                    return item.getFullType();
                }
            }
        } catch (Throwable throwable) {
            SAOAgent.log("carriedDisplayCategory threw: " + throwable);
        }
        return "";
    }

    public static ItemContainer nearestContainer(IsoPlayer shell, int radius) {
        try {
            zombie.iso.IsoCell cell = shell.getCell();
            if (cell == null) {
                return null;
            }
            int sx = (int) shell.getX();
            int sy = (int) shell.getY();
            int sz = (int) shell.getZ();
            ItemContainer best = null;
            int bestD = Integer.MAX_VALUE;
            for (int dx = -radius; dx <= radius; dx++) {
                for (int dy = -radius; dy <= radius; dy++) {
                    IsoGridSquare square = cell.getGridSquare(sx + dx, sy + dy, sz);
                    if (square == null) {
                        continue;
                    }
                    java.util.List<IsoObject> objects = square.getObjects();
                    for (int i = 0; i < objects.size(); i++) {
                        IsoObject object = objects.get(i);
                        int count = object.getContainerCount();
                        for (int c = 0; c < count; c++) {
                            ItemContainer container = object.getContainerByIndex(c);
                            if (container != null) {
                                int d = dx * dx + dy * dy;
                                if (d < bestD) {
                                    best = container;
                                    bestD = d;
                                }
                            }
                        }
                    }
                }
            }
            return best;
        } catch (Throwable throwable) {
            return null;
        }
    }

    /** First edible item in any container on this square, else null. */
    private static FoodSource firstFoodIn(IsoGridSquare square) {
        java.util.List<IsoObject> objects = square.getObjects();
        for (int i = 0; i < objects.size(); i++) {
            IsoObject object = objects.get(i);
            int count = object.getContainerCount();
            for (int c = 0; c < count; c++) {
                ItemContainer container = object.getContainerByIndex(c);
                if (container == null) {
                    continue;
                }
                java.util.ArrayList<InventoryItem> items = container.getItems();
                for (int k = 0; k < items.size(); k++) {
                    InventoryItem item = items.get(k);
                    if (edible(item)) {
                        FoodSource source = new FoodSource();
                        source.container = container;
                        source.item = item;
                        source.x = square.getX();
                        source.y = square.getY();
                        source.z = square.getZ();
                        return source;
                    }
                }
            }
        }
        return null;
    }

    /** The remembered source's item, revalidated, or null. */
    public static InventoryItem sourceItem(IsoPlayer shell) {
        FoodSource source = validSource(shell);
        return source == null ? null : source.item;
    }

    /** The remembered source's container, revalidated, or null. */
    public static ItemContainer sourceContainer(IsoPlayer shell) {
        FoodSource source = validSource(shell);
        return source == null ? null : source.container;
    }

    /** Adjacency check: standing close enough to take from the source. */
    public static boolean sourceWithinReach(IsoPlayer shell) {
        // [B50] Guarded, not argued. `getX()` returning a field
        // is almost certainly incapable of throwing - and the
        // bridge's contract is that Lua NEVER sees a Java throw,
        // because it arrives inside a pcall and turns into the
        // county quietly doing less ([B42], [B44]). A contract
        // that holds because somebody reasoned about getX() is
        // weaker than one that holds by construction.
        try {
            FoodSource source = SOURCES.get(shell);
            if (source == null) {
                return false;
            }
            float dx = shell.getX() - (source.x + 0.5f);
            float dy = shell.getY() - (source.y + 0.5f);
            return (dx * dx + dy * dy) <= 4.0f;
        } catch (Throwable throwable) {
            return false;
        }
    }

    public static void clearSource(IsoPlayer shell) {
        SOURCES.remove(shell);
    }

    private static FoodSource validSource(IsoPlayer shell) {
        try {
            FoodSource source = SOURCES.get(shell);
            if (source == null || source.container == null || source.item == null) {
                return null;
            }
            if (!source.container.contains(source.item)) {
                SOURCES.remove(shell);
                return null;
            }
            return source;
        } catch (Throwable throwable) {
            return null;
        }
    }

    /** Fluids a survivor will willingly drink for thirst. */
    private static boolean drinkable(zombie.entity.components.fluids.Fluid fluid) {
        return fluid == zombie.entity.components.fluids.Fluid.Water
            || fluid == zombie.entity.components.fluids.Fluid.SodaPop
            || fluid == zombie.entity.components.fluids.Fluid.Tea
            || fluid == zombie.entity.components.fluids.Fluid.Coffee;
    }

    /** Best carried drinkable (fullest wins), or null. */
    /** [B31] How much drinkable fluid a carried item holds, or -1
     *  when it is not a drink at all.
     *
     *  `bestCarriedDrink` and `spareDrink` each carried this whole
     *  test and differed only in what they kept afterwards - one the
     *  best, the other the best and the second. Teach the mod that
     *  some fluid is no longer safe and both learn it at once, which
     *  is the point of writing a thing down once ([B20], [B27],
     *  [B28]). */
    private static float drinkableAmount(InventoryItem item) {
        if (item == null) return -1.0f;
        zombie.entity.components.fluids.FluidContainer fluidContainer =
            item.getFluidContainer();
        if (fluidContainer == null || fluidContainer.isEmpty()) {
            return -1.0f;
        }
        zombie.entity.components.fluids.Fluid fluid =
            fluidContainer.getPrimaryFluid();
        if (fluid == null || !drinkable(fluid)) {
            return -1.0f;
        }
        return fluidContainer.getAmount();
    }

    public static InventoryItem bestCarriedDrink(IsoPlayer shell) {
        try {
            InventoryItem best = null;
            float bestAmount = 0.0f;
            java.util.ArrayList<InventoryItem> items = shell.getInventory().getItems();
            for (int i = 0; i < items.size(); i++) {
                InventoryItem item = items.get(i);
                float amount = drinkableAmount(item);
                if (amount < 0.0f) {
                    continue;
                }
                if (amount > bestAmount) {
                    bestAmount = amount;
                    best = item;
                }
            }
            return best;
        } catch (Throwable throwable) {
            return null;
        }
    }

    private static final Map<IsoPlayer, IsoObject> WATER_SOURCES = new WeakHashMap<>();

    /**
     * Nearest world object holding clean water (one floor up/down included,
     * penalized); remembered per shell, returned as "x:y:z" (true source
     * floor) or "". Tainted sources are refused.
     */
    /** [B31] This keeps its own sweep, deliberately.
     *
     *  Its loop order already matches `nearestOnFloorRing`, so nothing
     *  here drifted. What differs is what it FINDS. Food, weapons and
     *  ammo find an InventoryItem sitting in a container, which is
     *  exactly what FoodSource models. Water finds an IsoObject - a
     *  sink, a well, a fixture of the world that holds fluid and is
     *  not an item at all.
     *
     *  Folding it in would mean widening FoodSource to mean "an item,
     *  or else a world object", which makes the type lie about what it
     *  holds. The shared shape is a coincidence of iteration, not of
     *  purpose. */
    public static String findWaterSourceNear(IsoPlayer shell, int radius) {
        try {
            IsoCell cell = shell.getCell();
            if (cell == null) {
                return "";
            }
            int cx = (int) shell.getX();
            int cy = (int) shell.getY();
            int cz = (int) shell.getZ();
            IsoObject best = null;
            int bx = 0;
            int by = 0;
            int bz = cz;
            float bestDist = Float.MAX_VALUE;
            for (int zOff : FLOOR_RING) {
                for (int dy = -radius; dy <= radius; dy++) {
                    for (int dx = -radius; dx <= radius; dx++) {
                        float dist = dx * dx + dy * dy
                            + (zOff == 0 ? 0.0f : CROSS_FLOOR_PENALTY);
                        if (dist >= bestDist) {
                            continue;
                        }
                        IsoGridSquare square = cell.getGridSquare(cx + dx, cy + dy, cz + zOff);
                        if (square == null) {
                            continue;
                        }
                        java.util.List<IsoObject> objects = square.getObjects();
                        for (int i = 0; i < objects.size(); i++) {
                            IsoObject object = objects.get(i);
                            if (object.hasFluid() && object.getFluidAmount() > 0.1f
                                && !object.isTaintedWater()) {
                                best = object;
                                bx = square.getX();
                                by = square.getY();
                                bz = square.getZ();
                                bestDist = dist;
                                break;
                            }
                        }
                    }
                }
            }
            if (best == null) {
                WATER_SOURCES.remove(shell);
                return "";
            }
            WATER_SOURCES.put(shell, best);
            return bx + ":" + by + ":" + bz;
        } catch (Throwable throwable) {
            return "";
        }
    }

    /** The remembered water object, revalidated (still wet, still clean). */
    public static IsoObject waterSource(IsoPlayer shell) {
        try {
            IsoObject object = WATER_SOURCES.get(shell);
            if (object == null || !object.hasFluid()
                || object.getFluidAmount() <= 0.1f || object.isTaintedWater()) {
                WATER_SOURCES.remove(shell);
                return null;
            }
            return object;
        } catch (Throwable throwable) {
            return null;
        }
    }

    public static boolean waterSourceWithinReach(IsoPlayer shell) {
        try {
            IsoObject object = WATER_SOURCES.get(shell);
            if (object == null || object.getSquare() == null) {
                return false;
            }
            float dx = shell.getX() - (object.getSquare().getX() + 0.5f);
            float dy = shell.getY() - (object.getSquare().getY() + 0.5f);
            return (dx * dx + dy * dy) <= 4.0f;
        } catch (Throwable throwable) {
            return false;
        }
    }

    public static void clearWaterSource(IsoPlayer shell) {
        WATER_SOURCES.remove(shell);
    }

    private static final Map<IsoPlayer, FoodSource> WEAPON_SOURCES = new WeakHashMap<>();

    /** The survivor's current best melee score, empty hands included. */
    private static float carriedMeleeScore(IsoPlayer shell) {
        float best = 0.0f;
        java.util.ArrayList<InventoryItem> items = shell.getInventory().getItems();
        for (int i = 0; i < items.size(); i++) {
            float score = SAOEquipment.meleeScore(items.get(i));
            if (score > best) {
                best = score;
            }
        }
        return best;
    }

    /**
     * Nearest container weapon (one floor up/down included, penalized)
     * that beats what the survivor carries by a real margin (25%, minimum
     * +2). Remembered per shell; "x:y:z:<name>" or "".
     */
    /** [B31] What a floor-ring sweep is looking for on one square. */
    private interface SquareProbe {
        FoodSource on(IsoGridSquare square);
    }

    /** [B31] The nearest something across this floor and the two
     *  adjacent ones, found ONCE.
     *
     *  FOUR methods walked this same ring - food, water, a weapon
     *  upgrade, an ammo source - and the duplicate detector only
     *  matched two of them, which IS the finding: four copies of one
     *  search had already drifted apart. The two that were still
     *  identical are unified here.
     *
     *  findFoodSourceNear and findWaterSourceNear are deliberately
     *  NOT folded in. Unifying drifted code is a behaviour change
     *  wearing a refactor's clothes, and which variant is correct has
     *  to be answered before it is imposed on the rest. */
    private static FoodSource nearestOnFloorRing(
            IsoPlayer shell, int radius, SquareProbe probe) {
        IsoCell cell = shell.getCell();
        if (cell == null) return null;
        int cx = (int) shell.getX();
        int cy = (int) shell.getY();
        int cz = (int) shell.getZ();
        FoodSource best = null;
        float bestDist = Float.MAX_VALUE;
        for (int zOff : FLOOR_RING) {
            for (int dy = -radius; dy <= radius; dy++) {
                for (int dx = -radius; dx <= radius; dx++) {
                    float dist = dx * dx + dy * dy
                        + (zOff == 0 ? 0.0f : CROSS_FLOOR_PENALTY);
                    if (dist >= bestDist) {
                        continue;
                    }
                    IsoGridSquare square =
                        cell.getGridSquare(cx + dx, cy + dy, cz + zOff);
                    if (square == null) {
                        continue;
                    }
                    FoodSource found = probe.on(square);
                    if (found != null) {
                        best = found;
                        bestDist = dist;
                    }
                }
            }
        }
        return best;
    }

    public static String findWeaponUpgradeNear(IsoPlayer shell, int radius) {
        try {
            IsoCell cell = shell.getCell();
            if (cell == null) {
                return "";
            }
            float carried = carriedMeleeScore(shell);
            float threshold = Math.max(carried * 1.25f, carried + 2.0f);
            FoodSource best = nearestOnFloorRing(shell, radius,
                square -> firstWeaponIn(square, threshold));
            if (best == null) {
                WEAPON_SOURCES.remove(shell);
                return "";
            }
            WEAPON_SOURCES.put(shell, best);
            String name;
            try {
                name = best.item.getDisplayName();
            } catch (Throwable throwable) {
                name = "a weapon";
            }
            return best.x + ":" + best.y + ":" + best.z + ":" + name;
        } catch (Throwable throwable) {
            return "";
        }
    }

    private static FoodSource firstWeaponIn(IsoGridSquare square, float threshold) {
        java.util.List<IsoObject> objects = square.getObjects();
        for (int i = 0; i < objects.size(); i++) {
            IsoObject object = objects.get(i);
            int count = object.getContainerCount();
            for (int c = 0; c < count; c++) {
                ItemContainer container = object.getContainerByIndex(c);
                if (container == null) {
                    continue;
                }
                java.util.ArrayList<InventoryItem> items = container.getItems();
                for (int k = 0; k < items.size(); k++) {
                    InventoryItem item = items.get(k);
                    if (SAOEquipment.meleeScore(item) >= threshold) {
                        FoodSource source = new FoodSource();
                        source.container = container;
                        source.item = item;
                        source.x = square.getX();
                        source.y = square.getY();
                        source.z = square.getZ();
                        return source;
                    }
                }
            }
        }
        return null;
    }

    public static InventoryItem weaponSourceItem(IsoPlayer shell) {
        FoodSource source = validWeaponSource(shell);
        return source == null ? null : source.item;
    }

    public static ItemContainer weaponSourceContainer(IsoPlayer shell) {
        FoodSource source = validWeaponSource(shell);
        return source == null ? null : source.container;
    }

    public static boolean weaponSourceWithinReach(IsoPlayer shell) {
        // [B50] Guarded, not argued. `getX()` returning a field
        // is almost certainly incapable of throwing - and the
        // bridge's contract is that Lua NEVER sees a Java throw,
        // because it arrives inside a pcall and turns into the
        // county quietly doing less ([B42], [B44]). A contract
        // that holds because somebody reasoned about getX() is
        // weaker than one that holds by construction.
        try {
            FoodSource source = WEAPON_SOURCES.get(shell);
            if (source == null) {
                return false;
            }
            float dx = shell.getX() - (source.x + 0.5f);
            float dy = shell.getY() - (source.y + 0.5f);
            return (dx * dx + dy * dy) <= 4.0f;
        } catch (Throwable throwable) {
            return false;
        }
    }

    public static void clearWeaponSource(IsoPlayer shell) {
        WEAPON_SOURCES.remove(shell);
    }

    private static FoodSource validWeaponSource(IsoPlayer shell) {
        try {
            FoodSource source = WEAPON_SOURCES.get(shell);
            if (source == null || source.container == null || source.item == null) {
                return null;
            }
            if (!source.container.contains(source.item)) {
                WEAPON_SOURCES.remove(shell);
                return null;
            }
            return source;
        } catch (Throwable throwable) {
            return null;
        }
    }

    /** How many body parts are actively bleeding - for ANY character
     * ([A19]): a Knox neighbor's wound is as confirmable as a shell's,
     * so aid crosses the mod line on engine truth. */
    public static int bleedingCount(zombie.characters.IsoGameCharacter character) {
        try {
            return character.getBodyDamage().getNumPartsBleeding();
        } catch (Throwable throwable) {
            return 0;
        }
    }

    /** The worst (first) bleeding body part, as the opaque object the
     * vanilla bandage action constructor wants, or null. */
    public static Object worstBleedingPart(IsoPlayer shell) {
        try {
            zombie.characters.BodyDamage.BodyDamage damage = shell.getBodyDamage();
            for (zombie.characters.BodyDamage.BodyPartType type
                : zombie.characters.BodyDamage.BodyPartType.values()) {
                try {
                    if (damage.isBodyPartBleeding(type)) {
                        zombie.characters.BodyDamage.BodyPart part = damage.getBodyPart(type);
                        if (part != null && !part.bandaged()) {
                            return part;
                        }
                    }
                } catch (Throwable ignored) {
                    // MAX/synthetic enum entries have no part; skip.
                }
            }
            return null;
        } catch (Throwable throwable) {
            return null;
        }
    }

    /** A bandage this shell can GIVE AWAY ([A19]): the second one
     * carried, or the only one when the giver is not bleeding. */
    public static InventoryItem spareBandage(IsoPlayer shell) {
        try {
            var items = shell.getInventory().getItems();
            InventoryItem first = null;
            InventoryItem second = null;
            for (int i = 0; i < items.size(); i++) {
                InventoryItem item = items.get(i);
                if (item != null && item.isCanBandage()) {
                    if (first == null) {
                        first = item;
                    } else {
                        second = item;
                        break;
                    }
                }
            }
            if (second != null) {
                return second;
            }
            if (first != null && bleedingCount(shell) == 0) {
                return first;
            }
            return null;
        } catch (Throwable throwable) {
            return null;
        }
    }

    /** Best carried bandage-capable item (highest bandage power), or null. */
    public static InventoryItem bestBandage(IsoPlayer shell) {
        try {
            InventoryItem best = null;
            float bestPower = 0.0f;
            java.util.ArrayList<InventoryItem> items = shell.getInventory().getItems();
            for (int i = 0; i < items.size(); i++) {
                InventoryItem item = items.get(i);
                if (item.isCanBandage() && item.getBandagePower() > bestPower) {
                    bestPower = item.getBandagePower();
                    best = item;
                }
            }
            return best;
        } catch (Throwable throwable) {
            return null;
        }
    }

    /** The SECOND-best carried food - what a person can spare - or null
     * when sparing would empty their own stomach's prospects. */
    public static InventoryItem spareFood(IsoPlayer shell) {
        try {
            InventoryItem best = null;
            InventoryItem second = null;
            float bestFill = 0.0f;
            float secondFill = 0.0f;
            java.util.ArrayList<InventoryItem> items = shell.getInventory().getItems();
            for (int i = 0; i < items.size(); i++) {
                InventoryItem item = items.get(i);
                if (!edible(item)) {
                    continue;
                }
                float fill = -((Food) item).getHungChange();
                if (fill > bestFill) {
                    second = best;
                    secondFill = bestFill;
                    best = item;
                    bestFill = fill;
                } else if (fill > secondFill) {
                    second = item;
                    secondFill = fill;
                }
            }
            return second;
        } catch (Throwable throwable) {
            return null;
        }
    }

    /** Whether the shell carries something rippable into bandage rags:
     * a loose sheet, or clothing that is neither equipped nor worn. */
    public static boolean hasRippableCloth(IsoPlayer shell) {
        return findRippableCloth(shell) != null;
    }

    private static InventoryItem findRippableCloth(IsoPlayer shell) {
        try {
            java.util.ArrayList<InventoryItem> items = shell.getInventory().getItems();
            for (int i = 0; i < items.size(); i++) {
                InventoryItem item = items.get(i);
                if ("Base.Sheet".equals(item.getFullType())) {
                    return item;
                }
                if (item instanceof zombie.inventory.types.Clothing clothing
                    && !clothing.isEquipped() && !clothing.isWorn()) {
                    return item;
                }
            }
            return null;
        } catch (Throwable throwable) {
            return null;
        }
    }

    /** Consume one carried cloth into two ripped sheets. The CALLER charges
     * the time (hold state) before invoking; this is the terminal state of
     * the vanilla rip recipe, hand-rolled pending craft-system
     * comprehension. Returns what was ripped, or "". */
    public static String ripClothForRags(IsoPlayer shell) {
        try {
            InventoryItem cloth = findRippableCloth(shell);
            if (cloth == null) {
                return "";
            }
            String name;
            try {
                name = cloth.getDisplayName();
            } catch (Throwable throwable) {
                name = cloth.getFullType();
            }
            shell.getInventory().Remove(cloth);
            shell.getInventory().AddItem("Base.RippedSheets");
            shell.getInventory().AddItem("Base.RippedSheets");
            return name;
        } catch (Throwable throwable) {
            return "";
        }
    }

    private static final Map<IsoPlayer, FoodSource> AMMO_SOURCES = new WeakHashMap<>();

    /** Item full types that would feed any carried firearm: magazine type,
     * ammo box, and the loose-round item key. */
    private static java.util.Set<String> feedTypesFor(IsoPlayer shell) {
        java.util.Set<String> types = new java.util.HashSet<>();
        java.util.ArrayList<InventoryItem> items = shell.getInventory().getItems();
        for (int i = 0; i < items.size(); i++) {
            if (!(items.get(i) instanceof zombie.inventory.types.HandWeapon weapon)
                || !weapon.isRanged() || weapon.isBroken()) {
                continue;
            }
            try {
                String magazine = weapon.getMagazineType();
                if (magazine != null && !magazine.isEmpty()) {
                    types.add(magazine);
                }
            } catch (Throwable ignored) {
            }
            try {
                String box = weapon.getAmmoBox();
                if (box != null && !box.isEmpty()) {
                    types.add(box);
                }
            } catch (Throwable ignored) {
            }
            try {
                zombie.scripting.objects.AmmoType ammoType = weapon.getAmmoType();
                if (ammoType != null && ammoType.getItemKey() != null) {
                    types.add(ammoType.getItemKey());
                }
            } catch (Throwable ignored) {
            }
        }
        return types;
    }

    /** Whether the shell carries a dry firearm AND nothing that feeds it -
     * the state that justifies an ammo errand. */
    public static boolean needsAmmo(IsoPlayer shell) {
        try {
            boolean dryGun = false;
            java.util.Set<String> feeds = feedTypesFor(shell);
            if (feeds.isEmpty()) {
                return false;
            }
            java.util.ArrayList<InventoryItem> items = shell.getInventory().getItems();
            for (int i = 0; i < items.size(); i++) {
                InventoryItem item = items.get(i);
                if (item instanceof zombie.inventory.types.HandWeapon weapon
                    && weapon.isRanged() && !weapon.isBroken()
                    && SAOCombat.ammoCount(weapon) <= 0) {
                    dryGun = true;
                }
                if (feeds.contains(item.getFullType())) {
                    return false;   // something loadable is already carried
                }
            }
            return dryGun;
        } catch (Throwable throwable) {
            return false;
        }
    }

    /** Nearest container item feeding any carried firearm; remembered;
     * "x:y:z:<name>" or "". Same floor ring and penalty as every hunt. */
    public static String findAmmoSourceNear(IsoPlayer shell, int radius) {
        try {
            IsoCell cell = shell.getCell();
            if (cell == null) {
                return "";
            }
            java.util.Set<String> feeds = feedTypesFor(shell);
            if (feeds.isEmpty()) {
                return "";
            }
            FoodSource best = nearestOnFloorRing(shell, radius,
                square -> firstFeedIn(square, feeds));
            if (best == null) {
                AMMO_SOURCES.remove(shell);
                return "";
            }
            AMMO_SOURCES.put(shell, best);
            String name;
            try {
                name = best.item.getDisplayName();
            } catch (Throwable throwable) {
                name = "ammunition";
            }
            return best.x + ":" + best.y + ":" + best.z + ":" + name;
        } catch (Throwable throwable) {
            return "";
        }
    }

    private static FoodSource firstFeedIn(IsoGridSquare square, java.util.Set<String> feeds) {
        java.util.List<IsoObject> objects = square.getObjects();
        for (int i = 0; i < objects.size(); i++) {
            IsoObject object = objects.get(i);
            int count = object.getContainerCount();
            for (int c = 0; c < count; c++) {
                ItemContainer container = object.getContainerByIndex(c);
                if (container == null) {
                    continue;
                }
                java.util.ArrayList<InventoryItem> items = container.getItems();
                for (int k = 0; k < items.size(); k++) {
                    InventoryItem item = items.get(k);
                    if (feeds.contains(item.getFullType())) {
                        FoodSource source = new FoodSource();
                        source.container = container;
                        source.item = item;
                        source.x = square.getX();
                        source.y = square.getY();
                        source.z = square.getZ();
                        return source;
                    }
                }
            }
        }
        return null;
    }

    public static InventoryItem ammoSourceItem(IsoPlayer shell) {
        FoodSource source = validFrom(AMMO_SOURCES, shell);
        return source == null ? null : source.item;
    }

    public static ItemContainer ammoSourceContainer(IsoPlayer shell) {
        FoodSource source = validFrom(AMMO_SOURCES, shell);
        return source == null ? null : source.container;
    }

    public static boolean ammoSourceWithinReach(IsoPlayer shell) {
        // [B50] Guarded, not argued. `getX()` returning a field
        // is almost certainly incapable of throwing - and the
        // bridge's contract is that Lua NEVER sees a Java throw,
        // because it arrives inside a pcall and turns into the
        // county quietly doing less ([B42], [B44]). A contract
        // that holds because somebody reasoned about getX() is
        // weaker than one that holds by construction.
        try {
            FoodSource source = AMMO_SOURCES.get(shell);
            if (source == null) {
                return false;
            }
            float dx = shell.getX() - (source.x + 0.5f);
            float dy = shell.getY() - (source.y + 0.5f);
            return (dx * dx + dy * dy) <= 4.0f;
        } catch (Throwable throwable) {
            return false;
        }
    }

    public static void clearAmmoSource(IsoPlayer shell) {
        AMMO_SOURCES.remove(shell);
    }

    /** Shared source revalidation for the remembered-source maps. */
    private static FoodSource validFrom(Map<IsoPlayer, FoodSource> map, IsoPlayer shell) {
        try {
            FoodSource source = map.get(shell);
            if (source == null || source.container == null || source.item == null) {
                return null;
            }
            if (!source.container.contains(source.item)) {
                map.remove(shell);
                return null;
            }
            return source;
        } catch (Throwable throwable) {
            return null;
        }
    }

    /** Direct engine eat - the same call vanilla's action makes at complete(). */
    public static boolean engineEat(IsoPlayer shell, InventoryItem item) {
        try {
            return shell.Eat(item, 1.0f, false);
        } catch (Throwable throwable) {
            return false;
        }
    }

    private static final Map<IsoPlayer, zombie.iso.objects.IsoWorldInventoryObject>
        OFFERED = new WeakHashMap<>();

    /** A useful item lying on the ground within arm's reach (2 tiles,
     * same floor): food worth eating, a bandage, or a weapon. Remembered
     * for the grab; "<display name>" or "". */
    public static String findOfferedItemNear(IsoPlayer shell) {
        try {
            IsoCell cell = shell.getCell();
            if (cell == null) {
                return "";
            }
            int cx = (int) shell.getX();
            int cy = (int) shell.getY();
            int cz = (int) shell.getZ();
            zombie.iso.objects.IsoWorldInventoryObject found = null;
            int usefulCount = 0;
            for (int dy = -2; dy <= 2; dy++) {
                for (int dx = -2; dx <= 2; dx++) {
                    IsoGridSquare square = cell.getGridSquare(cx + dx, cy + dy, cz);
                    if (square == null) {
                        continue;
                    }
                    java.util.ArrayList<zombie.iso.objects.IsoWorldInventoryObject>
                        ground = square.getWorldObjects();
                    for (int i = 0; i < ground.size(); i++) {
                        zombie.iso.objects.IsoWorldInventoryObject worldItem = ground.get(i);
                        if (worldItem == null) {
                            continue;
                        }
                        InventoryItem item = worldItem.getItem();
                        if (item == null) {
                            continue;
                        }
                        boolean useful = edible(item)
                            || item.isCanBandage()
                            || SAOEquipment.meleeScore(item) > 0;
                        if (useful) {
                            usefulCount++;
                            if (found == null) {
                                found = worldItem;
                            }
                        }
                    }
                }
            }
            // A lone item reads as offered or lost; a CLUSTER reads as
            // somebody's stockpile, and stockpiles are left alone - the
            // restraint that keeps a survivor out of the player's camp
            // stores without needing the camp to be a formal claim.
            if (found == null || usefulCount >= 3) {
                OFFERED.remove(shell);
                return "";
            }
            OFFERED.put(shell, found);
            String name;
            try {
                name = found.getItem().getDisplayName();
            } catch (Throwable throwable) {
                name = "something useful";
            }
            return name;
        } catch (Throwable throwable) {
            return "";
        }
    }

    /** The remembered ground item as the opaque object the vanilla grab
     * action wants, revalidated (still on a square), or null. */
    public static Object offeredWorldItem(IsoPlayer shell) {
        try {
            zombie.iso.objects.IsoWorldInventoryObject worldItem = OFFERED.get(shell);
            if (worldItem == null || worldItem.getSquare() == null
                || worldItem.getItem() == null) {
                OFFERED.remove(shell);
                return null;
            }
            return worldItem;
        } catch (Throwable throwable) {
            return null;
        }
    }

    public static void clearOffered(IsoPlayer shell) {
        OFFERED.remove(shell);
    }

    /** Named corpses lying within radius, as "name:x:y|name:x:y|...".
     * Identity filtering (which names were OUR people) is Lua's business;
     * this only reads what a passerby could see on the ground. */
    public static String findNamedCorpsesNear(IsoPlayer shell, int radius) {
        try {
            IsoCell cell = shell.getCell();
            if (cell == null) {
                return "";
            }
            int cx = (int) shell.getX();
            int cy = (int) shell.getY();
            int cz = (int) shell.getZ();
            StringBuilder out = new StringBuilder(64);
            for (int dy = -radius; dy <= radius; dy++) {
                for (int dx = -radius; dx <= radius; dx++) {
                    IsoGridSquare square = cell.getGridSquare(cx + dx, cy + dy, cz);
                    if (square == null) {
                        continue;
                    }
                    java.util.List<zombie.iso.objects.IsoDeadBody> bodies =
                        square.getDeadBodys();
                    if (bodies == null) {
                        continue;
                    }
                    for (int i = 0; i < bodies.size(); i++) {
                        zombie.iso.objects.IsoDeadBody dead = bodies.get(i);
                        if (dead == null) {
                            continue;
                        }
                        zombie.characters.SurvivorDesc desc = dead.getDescriptor();
                        String name = desc == null ? null : desc.getForename();
                        if (name == null || name.isEmpty()) {
                            continue;
                        }
                        String deadSurname = desc.getSurname();
                        if (deadSurname != null && !deadSurname.isEmpty()) {
                            name = name + " " + deadSurname;   // [A24]
                        }
                        if (out.length() > 0) {
                            out.append('|');
                        }
                        out.append(name.replace('|', '_').replace(':', '_'))
                            .append(':').append(square.getX())
                            .append(':').append(square.getY());
                    }
                }
            }
            return out.toString();
        } catch (Throwable throwable) {
            return "";
        }
    }

    /** The SECOND-best carried drinkable - what a person can spare. */
    public static InventoryItem spareDrink(IsoPlayer shell) {
        try {
            InventoryItem best = null;
            InventoryItem second = null;
            float bestAmount = 0.0f;
            float secondAmount = 0.0f;
            java.util.ArrayList<InventoryItem> items = shell.getInventory().getItems();
            for (int i = 0; i < items.size(); i++) {
                InventoryItem item = items.get(i);
                float amount = drinkableAmount(item);
                if (amount < 0.0f) {
                    continue;
                }
                if (amount > bestAmount) {
                    second = best;
                    secondAmount = bestAmount;
                    best = item;
                    bestAmount = amount;
                } else if (amount > secondAmount) {
                    second = item;
                    secondAmount = amount;
                }
            }
            return second;
        } catch (Throwable throwable) {
            return null;
        }
    }

    /** Best carried smokable (the vanilla SMOKABLE tag), or null. */
    public static InventoryItem carriedSmokable(IsoPlayer shell) {
        try {
            java.util.ArrayList<InventoryItem> items = shell.getInventory().getItems();
            for (int i = 0; i < items.size(); i++) {
                InventoryItem item = items.get(i);
                if (item.hasTag(zombie.scripting.objects.ItemTag.SMOKABLE)) {
                    return item;
                }
            }
            return null;
        } catch (Throwable throwable) {
            return null;
        }
    }

    /** How many smokables the shell carries. */
    public static int smokableCount(IsoPlayer shell) {
        try {
            int count = 0;
            java.util.ArrayList<InventoryItem> items = shell.getInventory().getItems();
            for (int i = 0; i < items.size(); i++) {
                if (items.get(i).hasTag(zombie.scripting.objects.ItemTag.SMOKABLE)) {
                    count++;
                }
            }
            return count;
        } catch (Throwable throwable) {
            return 0;
        }
    }

    /** Visibly unkempt: any worn clothing dirty or bloody (vanilla
     * fields - what a passerby actually sees). */
    public static boolean isUnkempt(zombie.characters.IsoGameCharacter character) {
        try {
            java.util.ArrayList<InventoryItem> items =
                character.getInventory().getItems();
            for (int i = 0; i < items.size(); i++) {
                InventoryItem item = items.get(i);
                if (item instanceof zombie.inventory.types.Clothing clothing
                    && (clothing.isWorn() || clothing.isEquipped())
                    && (clothing.isDirty() || clothing.isBloody())) {
                    return true;
                }
            }
            return false;
        } catch (Throwable throwable) {
            return false;
        }
    }

    /** The BEST carried food - for the bonded, the spare-only rule does
     * not apply: the last meal goes to them. */
    public static InventoryItem bestFoodForBonded(IsoPlayer shell) {
        return bestCarriedFood(shell);
    }

    /** Sleep flag control (F-016: safe but inert off-slot - no engine
     * system recovers a non-slot sleeper, so REST charges recovery
     * itself). */
    public static void setShellAsleep(IsoPlayer shell, boolean asleep) {
        try {
            shell.setAsleep(asleep);
        } catch (Throwable ignored) {
        }
    }

    /** Charge rest recovery for elapsed in-game hours: full fatigue
     * recovery over ~8 hours (engine-approximate), endurance refills
     * faster. Direct stat mutation in the LOADED world - the same honest
     * deviation class as rag-rip: no vanilla surface exists for non-slot
     * sleepers, time is charged in real ticks. Returns the new fatigue. */
    public static float restRecoverTick(IsoPlayer shell, double hoursDelta) {
        try {
            zombie.characters.Stats stats = shell.getStats();
            float fatigue = stats.get(CharacterStat.FATIGUE);
            float endurance = stats.get(CharacterStat.ENDURANCE);
            fatigue = Math.max(0.0f, fatigue - (float) (hoursDelta / 8.0));
            endurance = Math.min(1.0f, endurance + (float) (hoursDelta / 4.0));
            stats.set(CharacterStat.FATIGUE, fatigue);
            stats.set(CharacterStat.ENDURANCE, endurance);
            return fatigue;
        } catch (Throwable throwable) {
            return -1.0f;
        }
    }

    /** Whether the character's own action stack still holds work. */
    public static boolean busy(IsoPlayer shell) {
        try {
            return !shell.getCharacterActions().isEmpty();
        } catch (Throwable throwable) {
            return false;
        }
    }
}
