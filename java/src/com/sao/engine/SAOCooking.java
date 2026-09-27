package com.sao.engine;

import java.util.ArrayList;
import java.util.Comparator;
import java.lang.ref.WeakReference;
import java.util.WeakHashMap;
import se.krka.kahlua.vm.KahluaTable;
import zombie.Lua.LuaManager;
import zombie.characters.IsoPlayer;
import zombie.inventory.InventoryItem;
import zombie.inventory.ItemContainer;
import zombie.inventory.types.Food;
import zombie.iso.IsoGridSquare;
import zombie.iso.IsoObject;
import zombie.iso.objects.IsoBarbecue;
import zombie.iso.objects.IsoFireplace;
import zombie.iso.objects.IsoStove;
import zombie.characters.skills.PerkFactory;
import zombie.scripting.objects.ItemTag;

/** Physical offers and exact thermal receipts. Native updates own cooking. */
public final class SAOCooking {
    private SAOCooking() { }
    private static final String BINDING = "SAOCookingBinding";
    private static final String CHEF = "SAOCookingChef";
    private static final String CREDIT = "SAOCookingCredit";
    private static final int APPROACH_RANGE = 14;
    private record Heat(String work, String actor, Object ownerToken, String binding,
            WeakReference<Food> item, WeakReference<IsoObject> appliance,
            WeakReference<ItemContainer> container, int itemId, float before) { }
    private static final WeakHashMap<IsoPlayer, Heat> heat = new WeakHashMap<>();
    private record Appliance(IsoObject object, ItemContainer container,
            IsoGridSquare approach, String sourceId, double distance) { }

    private static boolean live(IsoPlayer body) {
        return body != null && !body.isDead() && !body.isAsleep() && body.isExistInTheWorld()
            && body.getCell() != null
            && body.getSquare() != null && body.getInventory() != null;
    }
    private static boolean offSlot(IsoPlayer body) {
        if (!(body instanceof SAOIsoPlayerShell)) return false;
        for (IsoPlayer player : IsoPlayer.players) if (player == body) return false;
        return !zombie.network.GameClient.client && !zombie.network.GameServer.server;
    }
    private static Heat exact(IsoPlayer body, String work) {
        Heat value = heat.get(body);
        if (value == null || !value.work().equals(work) || !live(body) || !offSlot(body)
                || !value.actor().equals(String.valueOf(body.getModData().rawget("SAOPersonId")))
                || !java.util.Objects.equals(value.ownerToken(), body.getModData().rawget("SAOExternalToken"))) return null;
        Food food = value.item().get(); ItemContainer container = value.container().get();
        if (food == null || container == null || food.getID() != value.itemId()
                || food.getContainer() != container || !container.getItems().contains(food)
                || !value.binding().equals(food.getModData().rawget(BINDING))
                || food.getModData().rawget(CREDIT) == null && food.getChef() != null
                || inspect(body, value.appliance().get(), container) == null) return null;
        return value;
    }
    /** Bind the actual deposited raw item; no cooking fields are written. */
    public static boolean beginHeat(IsoPlayer body, String work, InventoryItem item,
            IsoObject appliance, ItemContainer container) {
        if (!live(body) || !offSlot(body) || work == null || work.isEmpty() || work.length() > 160
                || container == null || !(item instanceof Food food) || !raw(food) || food.getContainer() != container
                || !container.getItems().contains(food) || inspect(body, appliance, container) == null) return false;
        Object actorId = body.getModData().rawget("SAOPersonId");
        if (!(actorId instanceof String actor) || actor.isEmpty()) return false;
        Heat previous = heat.get(body);
        if (previous != null) return previous.work().equals(work) && exact(body, work) != null;
        for (Heat other : heat.values()) if (other.item().get() == food) return false;
        // An old saved binding has no live owner after reload. Restore only its
        // private attribution before beginning a new, separately receipted act.
        if (food.getModData().rawget(BINDING) != null) restoreChef(food);
        String binding = actor + "|" + work;
        food.getModData().rawset(CHEF, food.getChef());
        food.getModData().rawset(BINDING, binding);
        food.setChef(null); // Native chef lookup only covers slotted players.
        heat.put(body, new Heat(work, actor, body.getModData().rawget("SAOExternalToken"), binding,
            new WeakReference<>(food), new WeakReference<>(appliance), new WeakReference<>(container),
            food.getID(), food.getCookingTime()));
        return true;
    }
    private static void restoreChef(Food food) {
        Object chef = food.getModData().rawget(CHEF);
        if (food.getChef() == null && chef instanceof String name) food.setChef(name);
        food.getModData().rawset(BINDING, null); food.getModData().rawset(CHEF, null);
    }
    /** Detached native observations. Reads cannot grant XP or change heat. */
    public static KahluaTable heatState(IsoPlayer body, String work) {
        Heat value = exact(body, work);
        if (value == null) return null;
        Food food = value.item().get(); KahluaTable out = table();
        out.rawset("itemId", (double) food.getID()); out.rawset("actorId", value.actor());
        out.rawset("workId", value.work()); out.rawset("cooked", food.isCooked());
        out.rawset("burnt", food.isBurnt()); out.rawset("heat", (double) food.getHeat());
        out.rawset("beforeCookingTime", (double) value.before());
        out.rawset("cookingTime", (double) food.getCookingTime());
        out.rawset("progressed", food.getCookingTime() > value.before());
        out.rawset("credited", value.binding().equals(food.getModData().rawget(CREDIT)));
        return out;
    }
    /** Consume the exact native thermal result once, including off-slot XP. */
    public static KahluaTable completeHeat(IsoPlayer body, String work) {
        Heat value = exact(body, work);
        if (value == null) return null;
        Food food = value.item().get();
        // Native Food.update crosses the threshold strictly. setCooked(true)
        // itself only raises cookingTime to minutesToCook and is not evidence.
        if (!food.isCooked() || food.isBurnt() || food.getCookingTime() <= value.before()
                || food.getCookingTime() <= food.getMinutesToCook()) return null;
        Object credit = food.getModData().rawget(CREDIT);
        if (credit != null && !value.binding().equals(credit)) return null;
        if (credit == null) {
            food.getModData().rawset(CREDIT, value.binding());
            if (!food.isRotten() && !food.hasTag(ItemTag.NO_COOKING_XP)) {
                body.getXp().AddXP(PerkFactory.Perks.Cooking, 10.0f);
            }
        }
        // isCooked is now native true, so restoring the human name cannot
        // trigger the engine's one-time chef lookup on a later update.
        Object chef = food.getModData().rawget(CHEF);
        if (food.getChef() == null && chef instanceof String name) food.setChef(name);
        return heatState(body, work);
    }
    public static void clearHeat(IsoPlayer body, String work) {
        Heat value = heat.get(body);
        if (value == null || !value.work().equals(work)) return;
        Food food = value.item().get();
        if (food != null && value.binding().equals(food.getModData().rawget(BINDING))) restoreChef(food);
        heat.remove(body);
    }
    public static void reset() {
        for (Heat value : heat.values()) {
            Food food = value.item().get();
            if (food != null && value.binding().equals(food.getModData().rawget(BINDING))) restoreChef(food);
        }
        heat.clear();
    }
    private static String kind(IsoObject object) {
        if (object instanceof IsoStove) return "stove";
        if (object instanceof IsoFireplace) return "fireplace";
        if (object instanceof IsoBarbecue) return "barbecue";
        return null;
    }
    private static boolean raw(InventoryItem item) {
        return item instanceof Food food && food.isCookable()
            && !food.isCooked() && !food.isBurnt() && !food.isRotten();
    }
    private static double distance(IsoPlayer body, IsoGridSquare square) {
        double dx = body.getX() - square.getX(), dy = body.getY() - square.getY();
        return dx * dx + dy * dy;
    }
    private static KahluaTable table() { return LuaManager.platform.newTable(); }
    private static void position(KahluaTable row, String prefix, IsoGridSquare square) {
        row.rawset(prefix + "X", (double) square.getX());
        row.rawset(prefix + "Y", (double) square.getY());
        row.rawset(prefix + "Z", (double) square.getZ());
    }

    /** Visible appliance geometry and previously inspected raw food stay separate. */
    public static KahluaTable offers(IsoPlayer body, int radius) {
        KahluaTable out = table(), appliances = table(), foods = table();
        out.rawset("appliances", appliances); out.rawset("foods", foods);
        if (!live(body) || radius < 1 || radius > 14) return out;
        int bx = (int) Math.floor(body.getX()), by = (int) Math.floor(body.getY());
        int bz = (int) Math.floor(body.getZ());
        ArrayList<Appliance> found = new ArrayList<>();
        for (int y = by - radius; y <= by + radius; y++) {
            for (int x = bx - radius; x <= bx + radius; x++) {
                IsoGridSquare square = body.getCell().getGridSquare(x, y, bz);
                if (!SAOPerceptionScanner.canSeeWorldSquareNow(body, square, radius)) continue;
                IsoGridSquare approach = SAOWorldSources.interactionSquare(body, square);
                if (approach == null) continue;
                var objects = square.getObjects();
                for (int objectIndex = 0; objectIndex < objects.size(); objectIndex++) {
                    IsoObject object = objects.get(objectIndex);
                    if (kind(object) == null || object.getSquare() != square) continue;
                    for (int index = 0; index < object.getContainerCount(); index++) {
                        ItemContainer container = object.getContainerByIndex(index);
                        if (container == null || container.getParent() != object
                                || container.getOutermostContainer() != container) continue;
                        found.add(new Appliance(object, container, approach,
                            SAOWorldSources.privateContainerId(object, index), distance(body, square)));
                    }
                }
            }
        }
        found.sort(Comparator.comparingDouble(Appliance::distance).thenComparing(Appliance::sourceId));
        int number = 0;
        for (Appliance appliance : found) {
            if (number >= 16) break;
            KahluaTable row = table();
            row.rawset("object", appliance.object()); row.rawset("container", appliance.container());
            row.rawset("sourceId", appliance.sourceId()); row.rawset("kind", kind(appliance.object()));
            position(row, "source", appliance.object().getSquare());
            position(row, "approach", appliance.approach());
            row.rawset("reachable", SAONeeds.containerAccessibleNow(body, appliance.container()));
            appliances.rawset((double) ++number, row);
        }
        number = 0;
        for (SAOPrivateInventory.Holder holder : SAOPrivateInventory.loadedView(body, radius).holders()) {
            if (number >= 16) break;
            boolean carried = "carried".equals(holder.kind());
            if ((!carried && !"container".equals(holder.kind()) && !"vehicle".equals(holder.kind()))
                    || "refused".equals(holder.access()) || !"complete".equals(holder.contents())) continue;
            for (SAOPrivateInventory.ItemRef item : holder.items()) {
                if (number >= 16) break;
                if (!raw(item.item())) continue;
                ItemContainer container = item.item().getContainer();
                if (container == null) continue;
                IsoGridSquare square = carried ? body.getSquare()
                    : holder.container().getSourceGrid();
                if (square == null || square.getZ() != bz) continue;
                IsoGridSquare approach = carried ? square
                    : SAOWorldSources.interactionSquare(body, square);
                if (approach == null) continue;
                KahluaTable row = table();
                row.rawset("item", item.item()); row.rawset("container", container);
                row.rawset("worldContainer", carried ? null : holder.container());
                row.rawset("sourceId", holder.id()); row.rawset("carried", carried);
                row.rawset("itemId", (double) item.itemId()); row.rawset("itemType", item.fullType());
                row.rawset("reachable", carried || SAONeeds.containerAccessibleNow(body, holder.container()));
                position(row, "source", square); position(row, "approach", approach);
                foods.rawset((double) ++number, row);
            }
        }
        return out;
    }

    private static int attachedContainerIndex(IsoPlayer body, IsoObject object, ItemContainer container) {
        if (!live(body) || object == null || container == null || kind(object) == null) return -1;
        IsoGridSquare square = object.getSquare();
        if (square == null || square.getZ() != (int) Math.floor(body.getZ())
                || body.getCell().getGridSquare(square.getX(), square.getY(), square.getZ()) != square
                || !square.getObjects().contains(object) || container.getParent() != object
                || container.getSourceGrid() != square) return -1;
        for (int i = 0; i < object.getContainerCount(); i++) {
            if (object.getContainerByIndex(i) == container) return i;
        }
        return -1;
    }

    /** Fresh standable destination for the same privately selected appliance. */
    public static KahluaTable approach(IsoPlayer body, IsoObject object, ItemContainer container) {
        int index = attachedContainerIndex(body, object, container);
        if (index < 0) return null;
        IsoGridSquare square = object.getSquare();
        if (distance(body, square) > APPROACH_RANGE * APPROACH_RANGE) return null;
        IsoGridSquare target = SAOWorldSources.interactionSquare(body, square);
        if (target == null) return null;
        KahluaTable out = table();
        out.rawset("sourceId", SAOWorldSources.privateContainerId(object, index));
        position(out, "source", square); position(out, "approach", target);
        return out;
    }

    /** Inspect one exact appliance in reach; this read never toggles it. */
    public static KahluaTable inspect(IsoPlayer body, IsoObject object, ItemContainer container) {
        int index = attachedContainerIndex(body, object, container);
        if (index < 0 || !SAONeeds.containerAccessibleNow(body, container)) return null;
        KahluaTable out = table();
        out.rawset("sourceId", SAOWorldSources.privateContainerId(object, index));
        out.rawset("kind", kind(object));
        out.rawset("temperature", (double) container.getTemprature());
        if (object instanceof IsoStove stove) {
            out.rawset("active", stove.Activated()); out.rawset("powered", container.isPowered());
        } else if (object instanceof IsoFireplace fire) {
            out.rawset("active", fire.isLit()); out.rawset("fuel", (double) fire.getFuelAmount());
        } else if (object instanceof IsoBarbecue barbecue) {
            out.rawset("active", barbecue.isLit()); out.rawset("fuel", (double) barbecue.getFuelAmount());
        }
        return out;
    }
}
