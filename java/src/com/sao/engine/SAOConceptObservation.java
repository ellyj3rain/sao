package com.sao.engine;

import java.util.Collections;
import java.util.HashSet;
import java.util.IdentityHashMap;
import java.util.Locale;
import java.util.Set;
import se.krka.kahlua.vm.KahluaTable;
import zombie.Lua.LuaManager;
import zombie.characters.IsoPlayer;
import zombie.iso.IsoGridSquare;
import zombie.iso.IsoObject;
import zombie.iso.IsoWorld;
import zombie.iso.objects.IsoDoor;
import zombie.iso.objects.IsoThumpable;
import zombie.iso.objects.IsoWorldInventoryObject;
import zombie.vehicles.BaseVehicle;

/** Visible geometry and object vocabulary. Associations and inquiry belong to the person's Lua owners. */
public final class SAOConceptObservation {
    private SAOConceptObservation() { }
    private static final int MAX_OBSERVATIONS = 128, MAX_FRONTIERS = 32;
    private static final int[][] NEIGHBORS = {{0, -1}, {-1, 0}, {0, 1}, {1, 0}};

    static String actor(SAOIsoPlayerShell body) {
        if (body == null || !SAOSenses.awakeHuman(body) || !body.isExistInTheWorld()
                || body.getCell() == null || body.getCell() != IsoWorld.instance.currentCell
                || body.getCurrentSquare() == null
                || body.getCell().getGridSquare((int) Math.floor(body.getX()),
                    (int) Math.floor(body.getY()), (int) Math.floor(body.getZ())) != body.getCurrentSquare()) return null;
        for (IsoPlayer player : IsoPlayer.players) if (player == body) return null;
        var data = body.getModData();
        if (data.rawget("SAOExternalOwner") != null || Boolean.TRUE.equals(data.rawget("ZAOOwned"))) return null;
        // Ordinary SAO bodies have no external token. Lua validates exact active ownership and token agreement.
        Object identity = data.rawget("SAOPersonId");
        return identity instanceof String id && !id.isBlank() && id.length() <= 128 ? id : null;
    }

    // Native learned meaning is consulted only for exact privately carried food.
    // This never resolves arbitrary recipe labels into an invented operating method.
    private static String poisonBasis(SAOIsoPlayerShell body, zombie.inventory.InventoryItem item) {
        if (!body.isKnownPoison(item)) return "unrecognized";
        if (item.hasTag(zombie.scripting.objects.ItemTag.SHOW_POISON)) return "visible-warning";
        var food = (zombie.inventory.types.Food) item;
        if (food.getHerbalistType() != null && !food.getHerbalistType().isEmpty()
                && body.isRecipeActuallyKnown("Herbalist")) return "known-recipe:Herbalist";
        if (food.getPoisonDetectionLevel() >= 0
                && body.getPerkLevel(zombie.characters.skills.PerkFactory.Perks.Cooking)
                    >= 10 - food.getPoisonDetectionLevel()) return "native-perk:Cooking";
        return "own-poison-addition";
    }
    private static boolean foodCandidate(zombie.inventory.InventoryItem item) {
        return item instanceof zombie.inventory.types.Food food && !food.isRotten()
            && Float.isFinite(food.getHungChange()) && food.getHungChange() < 0.0f;
    }
    /** Scalar current personal recognition; unknown is not a safety finding. */
    public static KahluaTable foodKnowledge(SAOIsoPlayerShell body) {
        String actor = actor(body);
        if (actor == null) return null;
        var result = LuaManager.platform.newTable(); var rows = LuaManager.platform.newTable();
        result.rawset("schema", "sao.personal-food-knowledge/1"); result.rawset("actorId", actor);
        result.rawset("status", "available"); result.rawset("foods", rows);
        var items = SAOPrivateInventory.carriedItems(body);
        int count = 0, omitted = 0;
        Set<Long> seen = new HashSet<>();
        for (var item : items) {
            if (!foodCandidate(item) || !seen.add((long) item.getID())) continue;
            if (count >= 64) { omitted++; continue; }
            var food = (zombie.inventory.types.Food) item; var row = LuaManager.platform.newTable();
            String basis = poisonBasis(body, item);
            row.rawset("itemId", (double) item.getID()); row.rawset("itemType", item.getFullType());
            row.rawset("relief", (double) -food.getHungChange());
            row.rawset("recognizedPoison", !basis.equals("unrecognized")); row.rawset("basis", basis);
            rows.rawset((double) ++count, row);
        }
        result.rawset("omitted", (double) omitted);
        return result;
    }
    /** Revalidate the exact current candidate before handing it to a native action. */
    public static zombie.inventory.InventoryItem foodChoice(SAOIsoPlayerShell body, double itemId,
            String itemType, boolean recognizedPoison, String basis) {
        if (actor(body) == null || !Double.isFinite(itemId) || itemId != Math.floor(itemId)) return null;
        for (var item : SAOPrivateInventory.carriedItems(body)) {
            if (item.getID() != itemId || !item.getFullType().equals(itemType) || !foodCandidate(item)) continue;
            String current = poisonBasis(body, item);
            if (current.equals(basis) && recognizedPoison == !current.equals("unrecognized")) return item;
            return null;
        }
        return null;
    }

    private static String coordinate(IsoGridSquare square) {
        return square.getX() + ":" + square.getY() + ":" + square.getZ();
    }
    private static int exteriorDirection(int dx, int dy) {
        int x = Integer.compare(dx, 0), y = Integer.compare(dy, 0);
        return (y + 1) * 3 + x + 1;
    }
    private static void position(KahluaTable row, IsoGridSquare square) {
        row.rawset("x", square.getX() + 0.5); row.rawset("y", square.getY() + 0.5);
        row.rawset("z", (double) square.getZ());
    }
    private static void place(KahluaTable row, IsoGridSquare square, boolean occupiedRoom) {
        var building = square.getBuildingDef();
        if (building != null) row.rawset("buildingId", Long.toString(building.getID()));
        // Object coordinates do not reveal the native category of an unvisited room.
        if (occupiedRoom && square.getRoomDef() != null) row.rawset("roomId", Long.toString(square.getRoomDef().getID()));
    }
    private static String vocabulary(String value) {
        if (value == null) return null;
        String normalized = value.trim().toLowerCase(Locale.ROOT).replace(' ', '-');
        return normalized.matches("[a-z][a-z0-9_-]{0,63}") ? normalized : null;
    }
    private static String objectConcept(IsoObject object) {
        // The source persists the aquarium's physical furniture and renders
        // occupied/water/dry appearances from this table. Private diagnosis,
        // animal health and ownership never enter the visible projection.
        if (object.hasModData() && object.getModData().rawget("KnoxAquarium") instanceof KahluaTable)
            return "aquarium";
        var properties = object.getProperties();
        if (object.getSprite() != null) {
            String sprite = object.getSprite().getName();
            if (sprite != null && sprite.matches("pa_recreational_[2-5]")) return "claw-machine";
        }
        if (properties != null && "arcade_clawmachine".equals(vocabulary(properties.get("GroupName"))))
            return "claw-machine";
        String name = properties == null ? null : vocabulary(properties.get("CustomName"));
        if (name != null) {
            String group = vocabulary(properties.get("GroupName"));
            if (name.equals("painting") && ("easelcanvas".equals(group)
                    || "easelcanvassmall".equals(group) || "easelcanvaslarge".equals(group))) return "art-canvas";
            if (name.equals("sculpting") && "stationwork".equals(group)) return "art-sculpture";
            if (name.equals("microphone") && "standing".equals(group)) return "microphone";
            if (name.equals("jukebox")) return "jukebox";
            if (name.equals("booth") && object.getSprite()!=null) {
                String sprite=object.getSprite().getName();
                if ("ls_djbooth_01_1".equals(sprite)||"ls_djbooth_01_4".equals(sprite)) return "dj-booth";
                if (sprite!=null&&sprite.matches("ls_djbooth_01_[0235]")) return "dj-booth-part";
            }
            if (name.equals("hamster-wheel") && "human".equals(group)) return "fitness-treadmill";
            if (name.equals("contraption") && "fitness".equals(group)) return "fitness-bench";
            if (name.equals("table") && "ping-pong".equals(group) && object.getSprite()!=null
                    && object.getSprite().getName()!=null && object.getSprite().getName().matches("LS_Recreation_[0-3]")) return "ping-pong-table";
            if (name.equals("bed") || name.endsWith("-bed") || name.equals("mattress")) return "bed";
            if (name.equals("sink") || name.endsWith("-sink")) return "sink";
            if (name.equals("stove") || name.equals("oven")) return "stove";
            if (name.equals("workbench")) return "workbench";
            if (name.equals("chair") || name.endsWith("-chair")) return "seat";
            if (name.equals("sofa") || name.equals("couch")) return "seat";
            if (name.equals("table") || name.endsWith("-table")) return "table";
        }
        if (properties != null && properties.has("BedType")) return "sleeping-furniture";
        if (object.getSprite() != null) {
            String sprite = object.getSprite().getName();
            if (sprite != null && sprite.matches("recreational_01_(8|9|12|13|28|29|30|31|40|41|48|49|108|109|99|96)")) return "piano";
            if (sprite != null && sprite.matches("floors_rugs_01_(4[89]|5[0-9])")) return "yoga-mat";
            if (sprite != null && sprite.matches("appliances_com_01_7[2-9]")) return "computer";
            if (sprite != null && (sprite.matches("recreational_01_(1[6-9]|2[0-4]|27)")
                    || sprite.matches("pa_arcades_([0-9]|[1-3][0-9])")
                    || sprite.matches("pa_complex_[0-9]")
                    || sprite.matches("pa_pinballs_(0|3|4|7|8|11|12|15|16|19|20|23|24|27)"))) return "arcade-machine";
        }
        if (object instanceof zombie.iso.objects.IsoRadio) return "audio-device";
        // A holder's physical presence says nothing about its contents.
        return object.getContainerCount() > 0 ? "container" : null;
    }
    private static String doorwayState(SAOIsoPlayerShell body, IsoObject object) {
        if (object instanceof IsoDoor door) {
            if (door.getBarricadeForCharacter(body) != null) return "barricaded";
            return door.IsOpen() ? "open" : "closed";
        }
        if (object instanceof IsoThumpable door) {
            if (door.getBarricadeForCharacter(body) != null) return "barricaded";
            return door.IsOpen() ? "open" : "closed";
        }
        return "unknown";
    }

    public static KahluaTable observe(SAOIsoPlayerShell body, int radius) {
        String actor = actor(body);
        if (actor == null || radius < 1 || radius > 14) return null;
        KahluaTable result = LuaManager.platform.newTable(), observations = LuaManager.platform.newTable(),
            frontiers = LuaManager.platform.newTable(), approaches = LuaManager.platform.newTable();
        result.rawset("schema", "sao.concept-observation/1"); result.rawset("actorId", actor);
        result.rawset("status", "available"); result.rawset("coverage", "current-room-and-visible-loaded-tiles");
        result.rawset("observations", observations); result.rawset("frontiers", frontiers);
        result.rawset("approaches", approaches);
        var eye = body.getCurrentSquare(); var currentRoom = eye.getRoom();
        int observed = 0, frontierCount = 0, omittedObservations = 0, omittedFrontiers = 0;
        IsoGridSquare[] nearGround = new IsoGridSquare[9], farGround = new IsoGridSquare[9];
        if (currentRoom != null) {
            KahluaTable row = LuaManager.platform.newTable();
            row.rawset("key", "room:" + (eye.getRoomDef() == null ? coordinate(eye) : eye.getRoomDef().getID()));
            // Occupancy supplies geometric identity, never the map author's semantic room label.
            row.rawset("kind", "room"); row.rawset("concept", "room"); position(row, eye); place(row, eye, true);
            observations.rawset((double) ++observed, row);
        }
        Set<IsoObject> seenObjects = Collections.newSetFromMap(new IdentityHashMap<>());
        Set<String> seenFrontiers = new HashSet<>();
        for (int distance = 0; distance <= radius; distance++) {
            for (int dx = -distance; dx <= distance; dx++) for (int dy = -distance; dy <= distance; dy++) {
                if (Math.max(Math.abs(dx), Math.abs(dy)) != distance) continue;
                var square = body.getCell().getGridSquare(eye.getX() + dx, eye.getY() + dy, eye.getZ());
                if (!SAOPerceptionScanner.canSeeWorldSquareNow(body, square, radius)) continue;
                if (currentRoom == null && square.getRoom() == null && square.isSolidFloor()
                        && Math.max(Math.abs(dx), Math.abs(dy)) >= 2) {
                    int direction = exteriorDirection(dx, dy);
                    if (nearGround[direction] == null) nearGround[direction] = square;
                    farGround[direction] = square;
                }
                var objects = square.getObjects();
                for (int index = 0; index < Math.min(objects.size(), 128); index++) {
                    IsoObject object = objects.get(index);
                    // Loose items have a distinct native collection and exact item locator below.
                    if (object == null || object instanceof IsoWorldInventoryObject
                            || object.getSquare() != square || !seenObjects.add(object)) continue;
                    String concept = objectConcept(object);
                    if (concept == null) continue;
                    if (observed >= MAX_OBSERVATIONS) { omittedObservations++; continue; }
                    KahluaTable row = LuaManager.platform.newTable();
                    row.rawset("key", "object:" + coordinate(square) + ":" + index + ":" + concept);
                    row.rawset("kind", "object"); row.rawset("concept", concept); position(row, square);
                    row.rawset("objectIndex", (double) index);
                    row.rawset("runtimeInstance", Integer.toHexString(System.identityHashCode(object)));
                    var properties = object.getProperties();
                    if (properties != null) {
                        if (properties.get("CustomName") != null) row.rawset("customName", properties.get("CustomName"));
                        if (properties.get("GroupName") != null) row.rawset("groupName", properties.get("GroupName"));
                        if (properties.get("Facing") != null) row.rawset("facing", properties.get("Facing"));
                    }
                    if (object.getSprite() != null && object.getSprite().getName() != null)
                        row.rawset("spriteName", object.getSprite().getName());
                    if (concept.equals("aquarium")) {
                        var tank = (KahluaTable) object.getModData().rawget("KnoxAquarium");
                        row.rawset("aquariumMode", "dry".equals(tank.rawget("mode")) ? "dry" : "water");
                        row.rawset("aquariumOccupied", tank.rawget("fish") instanceof KahluaTable fish && fish.len() > 0);
                        Object water = tank.rawget("water");
                        row.rawset("aquariumWaterPresent", water instanceof Number amount
                            && Double.isFinite(amount.doubleValue()) && amount.doubleValue() > 0);
                    }
                    if (concept.equals("workbench") && object.getContainerCount() > 0) {
                        var holder = object.getContainerByIndex(0);
                        if (holder != null && holder.getParent() == object && holder.getSourceGrid() == square
                                && holder.getOutermostContainer() == holder) {
                            // Holder identity reveals no stock. Selected dispatch must obtain
                            // WorldSources' exact current fingerprint and physical approach.
                            try { row.rawset("sourceId", SAOWorldSources.privateContainerId(object, 0)); }
                            catch (IllegalArgumentException | IllegalStateException unavailable) { }
                        }
                    }
                    if(concept.equals("bed") || concept.equals("sleeping-furniture"))
                        row.rawset("recoverySourceId",SAORecoveryPlace.visibleSourceKey(body,object,radius));
                    place(row, square, currentRoom != null && square.getRoom() == currentRoom);
                    observations.rawset((double) ++observed, row);
                }
                omittedObservations += Math.max(0, objects.size() - 128);
                var worldObjects = square.getWorldObjects();
                for (int index = 0; index < Math.min(worldObjects.size(), 128); index++) {
                    var object = worldObjects.get(index);
                    if (object == null || object.getSquare() != square || !seenObjects.add(object)) continue;
                    var item = object.getItem();
                    if (item == null || item.getWorldItem() != object) continue;
                    if (observed >= MAX_OBSERVATIONS) { omittedObservations++; continue; }
                    var row = LuaManager.platform.newTable();
                    row.rawset("key", "world-item:" + coordinate(square) + ":" + index);
                    row.rawset("actorId", actor); row.rawset("kind", "object");
                    row.rawset("concept", "placed-item"); row.rawset("objectCollection", "worldObjects");
                    position(row, square); row.rawset("objectIndex", (double) index);
                    row.rawset("runtimeInstance", Integer.toHexString(System.identityHashCode(object)));
                    row.rawset("className", object.getClass().getName());
                    row.rawset("itemKey", Long.toString(item.getID())); row.rawset("itemType", item.getFullType());
                    place(row, square, currentRoom != null && square.getRoom() == currentRoom);
                    observations.rawset((double) ++observed, row);
                }
                omittedObservations += Math.max(0, worldObjects.size() - 128);
                // A personally visible approach in the occupied room supplies a doorway frontier.
                if (currentRoom == null || square.getRoom() != currentRoom || !square.isSolidFloor()) continue;
                for (int[] offset : NEIGHBORS) {
                    var next = body.getCell().getGridSquare(square.getX() + offset[0], square.getY() + offset[1], square.getZ());
                    if (next == null) continue;
                    IsoObject door = square.getDoorTo(next);
                    if (door == null) continue;
                    // The crossing may lead outside or into unknown space; far-side metadata stays unread.
                    if (square.getBuildingDef() == null) continue;
                    String from = coordinate(square), into = coordinate(next);
                    String key = "doorway:" + (from.compareTo(into) < 0 ? from + ":" + into : into + ":" + from);
                    if (!seenFrontiers.add(key)) continue;
                    if (frontierCount >= MAX_FRONTIERS) { omittedFrontiers++; continue; }
                    KahluaTable row = LuaManager.platform.newTable();
                    row.rawset("key", key); row.rawset("kind", "doorway"); position(row, square); place(row, square, true);
                    row.rawset("entryX", next.getX() + 0.5); row.rawset("entryY", next.getY() + 0.5);
                    row.rawset("entryZ", (double) next.getZ()); row.rawset("state", doorwayState(body, door));
                    frontiers.rawset((double) ++frontierCount, row);
                }
            }
        }
        int approachCount = 0;
        for (int direction = 0; direction < nearGround.length; direction++) {
            for (int span = 0; span < 2; span++) {
                var square = span == 0 ? nearGround[direction] : farGround[direction];
                if (square == null || (span == 1 && square == nearGround[direction])) continue;
                var row = LuaManager.platform.newTable();
                row.rawset("key", "ground:" + coordinate(square));
                row.rawset("kind", "visible-ground"); position(row, square);
                approaches.rawset((double) ++approachCount, row);
            }
        }
        // Loaded vehicles supply candidates only. Read no part/device state before
        // current personal visibility or exact passenger custody admits the vehicle.
        Set<BaseVehicle> vehicles = Collections.newSetFromMap(new IdentityHashMap<>());
        var occupiedVehicle = body.getVehicle();
        if (occupiedVehicle != null) vehicles.add(occupiedVehicle);
        int vehicleCandidates = 0;
        for (var vehicle : body.getCell().getVehicles()) {
            if (++vehicleCandidates > 128) { omittedObservations++; continue; }
            if (vehicle != null) vehicles.add(vehicle);
        }
        for (var vehicle : vehicles) {
            var square = vehicle.getSquare();
            if (square == null || square.getZ() != eye.getZ() || !Float.isFinite(vehicle.getZ())
                    || Math.floor(vehicle.getZ()) != square.getZ() || square.getCell() != body.getCell()
                    || body.getCell().getGridSquare(square.getX(), square.getY(), square.getZ()) != square
                    || vehicle.isRemovedFromWorld()) continue;
            int seat = occupiedVehicle == vehicle ? vehicle.getSeat(body) : -1;
            boolean custody = seat >= 0 && vehicle.getCharacter(seat) == body;
            if (!custody && !SAOPerceptionScanner.canSeeWorldSquareNow(body, square, radius)) continue;
            var part = vehicle.getParts().getPartById("Radio");
            if (part == null || part.getVehicle() != vehicle || !"Radio".equals(part.getId())) continue;
            var item = part.getInventoryItem();
            if (item == null) continue;
            if (observed >= MAX_OBSERVATIONS) { omittedObservations++; continue; }
            String vehicleInstance = Integer.toHexString(System.identityHashCode(vehicle));
            String partInstance = Integer.toHexString(System.identityHashCode(part));
            var row = LuaManager.platform.newTable();
            row.rawset("key", "vehicle-radio:" + vehicle.getId() + ":" + vehicle.getSqlId()
                + ":" + vehicleInstance + ":" + partInstance);
            row.rawset("actorId", actor); row.rawset("kind", "object"); row.rawset("concept", "audio-device");
            row.rawset("objectCollection", "vehicle"); position(row, square);
            row.rawset("vehicleId", (double) vehicle.getId()); row.rawset("vehicleSqlId", (double) vehicle.getSqlId());
            row.rawset("vehicleRuntimeInstance", vehicleInstance); row.rawset("partId", "Radio");
            row.rawset("partRuntimeInstance", partInstance); row.rawset("runtimeInstance", partInstance);
            row.rawset("className", part.getClass().getName());
            row.rawset("itemKey", Long.toString(item.getID())); row.rawset("itemType", item.getFullType());
            row.rawset("acquisition", custody ? "current-occupant" : "native-personal-visibility");
            place(row, square, currentRoom != null && square.getRoom() == currentRoom);
            observations.rawset((double) ++observed, row);
        }
        result.rawset("omittedObservations", (double) omittedObservations);
        result.rawset("omittedFrontiers", (double) omittedFrontiers);
        return result;
    }

    /** Selected private locator becomes a transient native object only while still visible. */
    public static IsoObject resolveVisibleObject(SAOIsoPlayerShell body, String key, String instance) {
        KahluaTable view = observe(body, 8);
        if (view == null || key == null || instance == null) return null;
        var rows = (KahluaTable) view.rawget("observations");
        for (int n = 1; n <= rows.len(); n++) {
            var row = (KahluaTable) rows.rawget((double) n);
            if (!key.equals(row.rawget("key")) || !instance.equals(row.rawget("runtimeInstance"))) continue;
            if (row.rawget("objectCollection") != null) return null;
            if (!(row.rawget("objectIndex") instanceof Number index)) return null;
            var square = body.getCell().getGridSquare(((Number)row.rawget("x")).intValue(),
                ((Number)row.rawget("y")).intValue(), ((Number)row.rawget("z")).intValue());
            if (square == null || index.intValue() < 0 || index.intValue() >= square.getObjects().size()) return null;
            var object = square.getObjects().get(index.intValue());
            return object != null && object.getSquare() == square
                && instance.equals(Integer.toHexString(System.identityHashCode(object))) ? object : null;
        }
        return null;
    }
}
