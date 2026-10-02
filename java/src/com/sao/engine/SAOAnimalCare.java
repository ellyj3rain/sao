package com.sao.engine;

import java.lang.ref.WeakReference;
import java.util.Map;
import java.util.Objects;
import java.util.WeakHashMap;
import zombie.characters.IsoPlayer;
import zombie.characters.animals.IsoAnimal;
import zombie.entity.components.fluids.Fluid;
import zombie.entity.components.fluids.FluidContainer;
import zombie.inventory.InventoryItem;
import zombie.inventory.ItemContainer;
import zombie.inventory.types.DrainableComboItem;
import zombie.inventory.types.Food;
import zombie.iso.IsoWorld;

/** Measures the exact native hand-feeding action. No food, XP or animal state is written here. */
public final class SAOAnimalCare {
    private static final int MAX_PENDING = 128;
    private static final float EPSILON = 0.000001f;
    private static final Map<IsoPlayer, Capture> PENDING = new WeakHashMap<>();
    private static long epoch = 1;
    private static long sequence;

    private SAOAnimalCare() { }

    private static final class Capture {
        final WeakReference<IsoAnimal> animal;
        final WeakReference<InventoryItem> item;
        final WeakReference<ItemContainer> container;
        final IsoWorld world;
        final String token, personId, itemType, unit;
        final Object owner, ownerToken;
        final int animalId, itemId;
        final FluidContainer fluid;
        final Fluid fluidType;
        float amount, hunger;
        boolean prepared;

        Capture(IsoPlayer body, IsoAnimal target, InventoryItem food, String key) {
            animal = new WeakReference<>(target);
            item = new WeakReference<>(food);
            container = new WeakReference<>(food.getContainer());
            world = IsoWorld.instance;
            token = key;
            personId = person(body);
            owner = body.getModData().rawget("SAOExternalOwner");
            ownerToken = body.getModData().rawget("SAOExternalToken");
            animalId = target.getAnimalID();
            itemId = food.getID();
            itemType = food.getFullType();
            fluid = food.getFluidContainer();
            fluidType = fluid == null ? null : fluid.getPrimaryFluid();
            unit = fluid != null ? "fluid" : food instanceof DrainableComboItem ? "uses" : "food-hunger";
            amount = quantity(food);
            hunger = target.getHunger();
        }
    }

    private static String person(IsoPlayer body) {
        Object id = body.getModData().rawget("SAOPersonId");
        return id == null ? "" : id.toString();
    }

    private static boolean finite(float value) { return Float.isFinite(value) && value >= 0; }

    private static boolean physical(IsoPlayer body, IsoAnimal animal) {
        if (body == null || animal == null || body == animal || body.isDead() || animal.isDead()
                || body instanceof SAOIsoPlayerShell shell && shell.removalPending
                || !body.isExistInTheWorld() || !animal.isExistInTheWorld()
                || body.getCell() == null || body.getCell() != animal.getCell()
                || body.getCell() != IsoWorld.instance.currentCell
                || body.getCurrentSquare() == null || animal.getCurrentSquare() == null
                || body.getCurrentSquare().getZ() != animal.getCurrentSquare().getZ()
                || Math.abs(body.getX() - animal.getX()) > 1.6f
                || Math.abs(body.getY() - animal.getY()) > 1.6f) return false;
        return body.getCurrentSquare().canReachTo(animal.getCurrentSquare());
    }

    /** Uses the animal's current definition, including external feed-type extensions. */
    public static boolean accepts(IsoPlayer body, IsoAnimal animal, InventoryItem food) {
        if (body == null || animal == null || food == null || !animal.canBeFeedByHand()
                || food.getOutermostContainer() != body.getInventory()
                || !body.getInventory().contains(food) || !finite(quantity(food)) || quantity(food) <= EPSILON)
            return false;
        var allowed = animal.getEatTypePossibleFromHand();
        if (allowed == null) return false;
        if (food.isAnimalFeed() && allowed.contains(food.getAnimalFeedType())) return true;
        if (allowed.contains(food.getFullType())) return true;
        if (food instanceof Food value && (allowed.contains(value.getFoodType())
                || allowed.contains(value.getMilkType()))) return true;
        var fluid = food.getFluidContainer();
        if (fluid == null || fluid.isEmpty()) return false;
        var breed = animal.getBreed();
        return allowed.contains("AnimalMilk") && fluid.isPureFluid(Fluid.AnimalMilk)
            || breed != null && breed.getMilkType() != null && allowed.contains(breed.getMilkType())
                && fluid.isPureFluid(Fluid.Get(breed.getMilkType()));
    }

    private static float quantity(InventoryItem food) {
        var fluid = food.getFluidContainer();
        if (fluid != null) return fluid.getAmount();
        if (food instanceof DrainableComboItem value) return value.getCurrentUses();
        if (food instanceof Food value) return -value.getHungerChange();
        return Float.NaN;
    }

    private static boolean identity(IsoPlayer body, Capture c, IsoAnimal animal, InventoryItem food) {
        return c.world == IsoWorld.instance && c.animal.get() == animal && c.item.get() == food
            && c.animalId == animal.getAnimalID() && c.itemId == food.getID()
            && c.itemType.equals(food.getFullType()) && c.personId.equals(person(body))
            && Objects.equals(c.owner, body.getModData().rawget("SAOExternalOwner"))
            && Objects.equals(c.ownerToken, body.getModData().rawget("SAOExternalToken"))
            && c.fluid == food.getFluidContainer()
            && (c.fluid == null || c.fluidType == c.fluid.getPrimaryFluid() || c.fluid.isEmpty());
    }

    public static String beginFeed(Object body, Object animal, Object food) {
        return body instanceof IsoPlayer player && animal instanceof IsoAnimal target && food instanceof InventoryItem item
            ? beginBoundFeed(player, target, item) : "";
    }

    public static boolean prepareFeed(Object body, String token, Object animal, Object food) {
        return body instanceof IsoPlayer player && animal instanceof IsoAnimal target && food instanceof InventoryItem item
            && prepareBoundFeed(player, token, target, item);
    }

    public static String finishFeed(Object body, String token, Object animal, Object food, boolean completed) {
        return body instanceof IsoPlayer player && animal instanceof IsoAnimal target && food instanceof InventoryItem item
            ? finishBoundFeed(player, token, target, item, completed) : "";
    }

    public static void cancelFeed(Object body, String token) {
        if (body instanceof IsoPlayer player) cancelBoundFeed(player, token);
    }

    /** One outstanding capture per body; tokens are current-world handles only. */
    private static synchronized String beginBoundFeed(IsoPlayer body, IsoAnimal animal, InventoryItem food) {
        if (!physical(body, animal) || !accepts(body, animal, food)
                || !finite(animal.getHunger()) || animal.getHunger() <= EPSILON
                || food.getFullType() == null || food.getFullType().isEmpty()
                || food.getFullType().length() > 160 || food.getFullType().indexOf('@') >= 0
                || food.getFullType().indexOf('|') >= 0) return "";
        // Observer saturation withholds learning, rather than preventing necessary physical care.
        if (PENDING.containsKey(body) || PENDING.size() >= MAX_PENDING) return "BUSY";
        var capture = new Capture(body, animal, food, "animal-feed/" + epoch + "/" + (++sequence));
        PENDING.put(body, capture);
        return capture.token;
    }

    /** The baseline is refreshed immediately before the installed action's complete call. */
    private static synchronized boolean prepareBoundFeed(IsoPlayer body, String token, IsoAnimal animal, InventoryItem food) {
        Capture c = PENDING.get(body);
        if (c == null || !c.token.equals(token)) return false;
        if (c.prepared || !physical(body, animal) || food == null || !identity(body, c, animal, food)
                || c.container.get() != food.getContainer() || !accepts(body, animal, food)
                || !finite(animal.getHunger()) || animal.getHunger() <= EPSILON) {
            PENDING.remove(body);
            return false;
        }
        c.amount = quantity(food);
        c.hunger = animal.getHunger();
        c.prepared = true;
        return true;
    }

    /** A terminal receipt is detached scalars; a consumed token cannot complete twice. */
    private static synchronized String finishBoundFeed(IsoPlayer body, String token, IsoAnimal animal,
            InventoryItem food, boolean completed) {
        Capture c = PENDING.get(body);
        if (c == null || !c.token.equals(token)) return "";
        PENDING.remove(body);
        if (animal == null || food == null || !physical(body, animal) || !identity(body, c, animal, food)) return "";
        float after = quantity(food), hunger = animal.getHunger();
        if (!finite(after) || !finite(hunger)) return "";
        // Native depletion may remove the item. A transfer into somebody else's container is not consumption.
        if (food.getContainer() != null && food.getContainer() != c.container.get()) return "";
        if (!body.getInventory().contains(food)) after = 0;
        String status = "interrupted", reason = "native-action-interrupted";
        if (completed && c.prepared) {
            if (c.amount - after > EPSILON && c.hunger - hunger > EPSILON) {
                status = "completed";
                reason = "native-feed-consumed";
            } else {
                status = "no-effect";
                reason = "native-feed-unmeasured";
            }
        }
        return status + "@" + c.token + "@" + c.animalId + "@" + c.itemId + "@" + c.itemType
            + "@" + c.unit + "@" + c.amount + "@" + after + "@" + c.hunger + "@" + hunger + "@" + reason;
    }

    private static synchronized void cancelBoundFeed(IsoPlayer body, String token) {
        Capture c = PENDING.get(body);
        if (c != null && c.token.equals(token)) PENDING.remove(body);
    }

    public static synchronized void forget(IsoPlayer body) { PENDING.remove(body); }

    public static synchronized void resetRuntimeForWorld() { PENDING.clear(); epoch++; }

    public static synchronized int pendingCount() { return PENDING.size(); }
}
