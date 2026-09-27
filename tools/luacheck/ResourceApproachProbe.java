import com.sao.engine.SAONeeds;
import java.lang.reflect.Method;
import zombie.characters.IsoPlayer;
import zombie.characters.SurvivorDesc;
import zombie.entity.Component;
import zombie.entity.GameEntity;
import zombie.entity.components.fluids.Fluid;
import zombie.entity.components.fluids.FluidContainer;
import zombie.inventory.InventoryItem;
import zombie.inventory.ItemContainer;
import zombie.inventory.types.Food;
import zombie.inventory.types.HandWeapon;
import zombie.inventory.types.InventoryContainer;
import zombie.iso.IsoCell;
import zombie.iso.IsoChunk;
import zombie.iso.IsoChunkMap;
import zombie.iso.IsoGridSquare;
import zombie.iso.IsoObject;
import zombie.iso.IsoWorld;
import zombie.iso.SpriteDetails.IsoFlagType;
import zombie.scripting.ScriptManager;
import zombie.scripting.objects.Item;
import zombie.scripting.objects.ItemType;
import zombie.scripting.objects.ScriptModule;
import zombie.world.DictionaryData;
import zombie.world.ItemInfo;
import zombie.world.WorldDictionary;

/** Installed native item, container, fluid and square methods; no game loop. */
public final class ResourceApproachProbe {
    private static int checks;
    private static short nextType = 700;
    private static int nextItem = 70000;
    private static final Dictionary DICTIONARY = new Dictionary();
    private static final ScriptModule MODULE = new ScriptModule();

    private static final class Info extends ItemInfo {
        Info(Item item, short id) {
            name = item.getName(); moduleName = "Approach";
            fullType = "Approach." + name; registryId = id;
            isLoaded = true; scriptItem = item; entityScript = item;
            modId = "fixture";
        }
    }

    private static final class Dictionary extends DictionaryData {
        void register(Item item, short id) {
            Info info = new Info(item, id);
            itemIdToInfoMap.put(id, info);
            itemTypeToInfoMap.put(info.getFullType(), info);
        }
    }

    private static InventoryItem item(String name, ItemType type) {
        short id = nextType++;
        Item definition = new Item();
        definition.setModule(MODULE); definition.setName(name);
        definition.setRegistry_id(id); definition.displayName = name;
        definition.setItemType(type);
        MODULE.items.getScriptMap().put(name, definition);
        DICTIONARY.register(definition, id);
        InventoryItem value = definition.InstanceItem(null, false);
        value.id = nextItem++;
        return value;
    }

    private static void check(String name, boolean condition) {
        System.out.println("CHECK " + name + "=" + condition);
        if (!condition) throw new AssertionError(name);
        checks++;
    }

    private static void initFluids() throws Exception {
        // The native script loader normally supplies these three provenance
        // fields before ParseScript. A fixture must supply the same context.
        var manager = zombie.scripting.ScriptManager.instance;
        var type = zombie.scripting.ScriptManager.class;
        var mod = type.getDeclaredField("currentLoadFileMod"); mod.setAccessible(true);
        var file = type.getDeclaredField("currentLoadFileName"); file.setAccessible(true);
        var absolute = type.getDeclaredField("currentLoadFileAbsPath"); absolute.setAccessible(true);
        Object oldMod=mod.get(null), oldFile=file.get(null), oldAbsolute=absolute.get(null);
        String oldCurrent = manager.currentFileName;
        try {
            mod.set(null, "pz-vanilla");
            for (String name : new String[]{"fluids.txt", "fluids_Beverages.txt", "fluids_Alcoholic.txt"}) {
                var game = java.nio.file.Path.of(IsoPlayer.class.getProtectionDomain().getCodeSource().getLocation().toURI()).getParent();
                var path = game.resolve("media/scripts/generated").resolve(name);
                file.set(null, name); absolute.set(null, path.toString()); manager.currentFileName=name;
                manager.ParseScript(zombie.scripting.ScriptLoadMode.Init,
                    zombie.scripting.ScriptParser.stripComments(java.nio.file.Files.readString(path)));
            }
            manager.getModule("Base").fluidDefinitionScripts.LoadScripts(zombie.scripting.ScriptLoadMode.Init);
            zombie.entity.components.fluids.Fluid.Init(zombie.scripting.ScriptLoadMode.Init);
        } finally {
            mod.set(null,oldMod); file.set(null,oldFile); absolute.set(null,oldAbsolute);
            manager.currentFileName=oldCurrent;
        }
        if (!zombie.entity.components.fluids.Fluid.Water.isCategory(zombie.entity.components.fluids.FluidCategory.Water)) {
            throw new AssertionError("installed Water category unavailable");
        }
    }

    private static IsoCell boot() throws Exception {
        zombie.core.random.RandStandard.INSTANCE.init();
        zombie.ZomboidFileSystem.instance.init();
        zombie.SoundManager.instance = new zombie.DummySoundManager();
        zombie.Lua.LuaManager.platform = new se.krka.kahlua.j2se.J2SEPlatform();
        zombie.Lua.LuaManager.env = zombie.Lua.LuaManager.platform.newTable();
        zombie.Lua.LuaEventManager.register(zombie.Lua.LuaManager.platform,
            zombie.Lua.LuaManager.env);
        SurvivorDesc.HairCommonColors.add(new zombie.core.ImmutableColor(.2f, .3f, .4f));
        var styles = new zombie.core.skinnedmodel.population.HairStyles();
        zombie.core.skinnedmodel.population.HairStyles.instance = styles;
        zombie.core.skinnedmodel.population.BeardStyles.instance =
            new zombie.core.skinnedmodel.population.BeardStyles();
        var hair = new zombie.core.skinnedmodel.population.HairStyle();
        hair.name = "fixture"; styles.maleStyles.add(hair); styles.femaleStyles.add(hair);
        var beard = new zombie.core.skinnedmodel.population.BeardStyle();
        beard.name = "fixture";
        zombie.core.skinnedmodel.population.BeardStyles.instance.styles.add(beard);
        zombie.GameTime.setInstance(new zombie.GameTime());
        zombie.GameTime.getInstance().updateCalendar(1993, 0, 1, 12, 0);
        zombie.characters.skills.PerkFactory.init();
        var dictionary = WorldDictionary.class.getDeclaredField("data");
        dictionary.setAccessible(true); dictionary.set(null, DICTIONARY);
        MODULE.name = "Approach";
        ScriptManager.instance.moduleMap.put(MODULE.name, MODULE);
        initFluids();
        IsoCell cell = new IsoCell(1, 1);
        zombie.iso.WorldReuserThread.instance.stop();
        IsoWorld.instance.currentCell = cell;
        var map = cell.getChunkMap(0);
        map.setInitialPos(2, 2); map.ignore = false;
        IsoPlayer.numPlayers = 1;
        for (int wx = 0; wx < 4; wx++) for (int wy = 1; wy < 4; wy++) {
            IsoChunk chunk = new IsoChunk(cell);
            chunk.wx = wx; chunk.wy = wy; chunk.loaded = true;
            for (int z = 0; z <= 1; z++) for (int x = 0; x < 8; x++) for (int y = 0; y < 8; y++) {
                var square = new IsoGridSquare(cell, null, wx * 8 + x, wy * 8 + y, z);
                square.chunk = chunk;
                square.getProperties().set(IsoFlagType.solidfloor);
                chunk.setSquare(x, y, z, square);
            }
            int ix = wx - map.getWorldXMin(), iy = wy - map.getWorldYMin();
            map.getChunks()[iy * IsoChunkMap.chunkGridWidth + ix] = chunk;
        }
        return cell;
    }

    private static IsoPlayer person(IsoCell cell) {
        var desc = new SurvivorDesc(false);
        desc.getHumanVisual().setSkinTextureName("fixture");
        var person = new IsoPlayer(cell, desc, 10, 20, 0, false);
        person.setX(10.5f); person.setY(20.5f); person.setZ(0);
        person.setCurrent(cell.getGridSquare(10, 20, 0));
        person.getModData().rawset("SAOPersonId", "approach-person");
        return person;
    }

    private static void blocked(IsoGridSquare square, boolean value) {
        if (value) square.getProperties().set(IsoFlagType.solidtrans);
        else square.getProperties().unset(IsoFlagType.solidtrans);
        square.setCachedIsFree(false);
    }

    private static IsoObject holder(IsoCell cell, int x, int y, int z) {
        var square = cell.getGridSquare(x, y, z);
        var object = new IsoObject(cell);
        object.setSprite(new zombie.iso.sprite.IsoSprite());
        object.setSquare(square);
        var container = new ItemContainer("counter", square, object);
        container.setExplored(true); object.setContainer(container);
        square.getObjects().add(object);
        blocked(square, true);
        return object;
    }

    private static void inspect(IsoPlayer person, IsoObject object) throws Exception {
        float x=person.getX(), y=person.getY(), z=person.getZ();
        IsoGridSquare here=person.getCurrentSquare(), source=object.getSquare();
        IsoGridSquare beside=person.getCell().getGridSquare(source.getX()-1,source.getY(),source.getZ());
        person.setX(beside.getX()+.5f); person.setY(beside.getY()+.5f); person.setZ(beside.getZ()); person.setCurrent(beside);
        try {
            String candidates=com.sao.engine.SAOWorldSources.inspectionCandidates(person,14);
            for (String line:candidates.split("\n")) if (line.startsWith("C|")) {
                var fields=new java.util.HashMap<String,String>();
                for(String part:line.substring(2).split("\\|")) {
                    int at=part.indexOf('='); fields.put(part.substring(0,at),part.substring(at+1));
                }
                if (!Integer.toString(source.getX()).equals(fields.get("sx"))
                    || !Integer.toString(source.getY()).equals(fields.get("sy"))
                    || !Integer.toString(source.getZ()).equals(fields.get("sz"))) continue;
                String result=com.sao.engine.SAOWorldSources.inspectContainer(person,fields.get("id"),fields.get("fp"),
                    source.getX(),source.getY(),source.getZ());
                if (!result.startsWith("I|source=")) throw new AssertionError("native own inspection: "+result);
                return;
            }
            throw new AssertionError("native inspection candidate absent: "+candidates);
        } finally {
            person.setX(x); person.setY(y); person.setZ(z); person.setCurrent(here);
        }
    }

    private static String approach(IsoPlayer person, String kind, int x, int y, int z) {
        return SAONeeds.resourceApproach(person, kind, x, y, z);
    }

    private static FluidContainer fluid(IsoObject object) throws Exception {
        object.setSprite(new zombie.iso.sprite.IsoSprite());
        FluidContainer fluid = FluidContainer.CreateContainer();
        fluid.setCapacity(4); fluid.addFluid(Fluid.Water, 2);
        Method attach = GameEntity.class.getDeclaredMethod("addComponent", Component.class);
        attach.setAccessible(true);
        if (!(Boolean) attach.invoke(object, fluid)) throw new AssertionError("fluid fixture");
        return fluid;
    }

    @SuppressWarnings("unchecked")
    private static void vehicle(IsoCell cell, IsoPlayer person,
            ItemContainer previous, InventoryContainer bag) throws Exception {
        var vehicle = new zombie.vehicles.BaseVehicle(cell);
        vehicle.setX(18.5f); vehicle.setY(20.5f); vehicle.setZ(0);
        vehicle.setCurrent(cell.getGridSquare(18, 20, 0));
        vehicle.jniTransform.setIdentity();
        vehicle.jniTransform.origin.set(18.5f, 0, 20.5f);
        var script = new zombie.scripting.objects.VehicleScript();
        var area = new zombie.scripting.objects.VehicleScript.Area();
        area.id = "CargoAccess"; area.x = -1; area.y = 0; area.w = 1; area.h = 1;
        var areas = zombie.scripting.objects.VehicleScript.class.getDeclaredField("areas");
        areas.setAccessible(true);
        ((java.util.List<zombie.scripting.objects.VehicleScript.Area>) areas.get(script)).add(area);
        var scriptField = zombie.vehicles.BaseVehicle.class.getDeclaredField("script");
        scriptField.setAccessible(true); scriptField.set(vehicle, script);
        var definition = new zombie.scripting.objects.VehicleScript.Part();
        definition.id = "Cargo"; definition.area = area.id;
        definition.container = new zombie.scripting.objects.VehicleScript.Container();
        definition.container.capacity = 40;
        var part = new zombie.vehicles.VehiclePart(vehicle);
        part.setScriptPart(definition);
        vehicle.getParts().add(part);
        var container = new ItemContainer(); container.setExplored(true);
        part.setItemContainer(container);
        previous.Remove(bag); container.AddItem(bag);
        cell.getVehicles().add(vehicle);
        blocked(cell.getGridSquare(18, 20, 0), true);
        check("native_vehicle_area_is_distinct", vehicle.getSquareForArea(area.id)
            == cell.getGridSquare(17, 20, 0) && vehicle.canAccessContainer(part.getIndex(), person));
        check("vehicle_query_preserves_source", SAONeeds.findFoodSourceNear(person, 12).startsWith("18:20:0:"));
        check("vehicle_native_part_target", "AT:17:20:0".equals(approach(person, "food", 18, 20, 0)));
        var containerDefinition = definition.container;
        definition.container = null;
        check("revoked_vehicle_permission_refused", "UNAVAILABLE".equals(approach(person, "food", 18, 20, 0)));
        definition.container = containerDefinition;
        vehicle.setX(19.5f);
        check("moved_vehicle_refused", "UNAVAILABLE".equals(approach(person, "food", 18, 20, 0)));
        vehicle.setX(18.5f);
        cell.getVehicles().remove(vehicle);
        check("removed_vehicle_refused", "UNAVAILABLE".equals(approach(person, "food", 18, 20, 0)));
        cell.getVehicles().add(vehicle);
        part.setItemContainer(new ItemContainer());
        check("replaced_vehicle_container_refused", "UNAVAILABLE".equals(approach(person, "food", 18, 20, 0)));
        part.setItemContainer(container);
        definition.area = "";
        check("missing_vehicle_area_refused", "UNAVAILABLE".equals(approach(person, "food", 18, 20, 0)));
        definition.area = area.id;
        blocked(cell.getGridSquare(17, 20, 0), true);
        check("blocked_vehicle_area_refused", "UNAVAILABLE".equals(approach(person, "food", 18, 20, 0)));
        blocked(cell.getGridSquare(17, 20, 0), false);
        check("vehicle_revalidation_restores_actual_target", "AT:17:20:0".equals(approach(person, "food", 18, 20, 0)));
        cell.getVehicles().remove(vehicle);
    }

    public static void main(String[] args) throws Exception {
        IsoCell cell = boot();
        IsoPlayer person = person(cell);
        for (String kind : new String[] {"food", "water", "weapon", "ammo"}) {
            check("no_receipt_" + kind, "NONE".equals(approach(person, kind, 12, 20, 0)));
        }
        check("bad_kind_refused", "UNAVAILABLE".equals(approach(person, "drug", 12, 20, 0)));
        IsoObject cabinet = holder(cell, 12, 20, 0);
        ItemContainer root = cabinet.getContainer();
        InventoryContainer bag = (InventoryContainer) item("Bag", ItemType.CONTAINER);
        Food food = (Food) item("Meal", ItemType.FOOD);
        food.setHungChange(-.3f); food.setAge(0);
        bag.getInventory().AddItem(food); root.AddItem(bag);
        HandWeapon weapon = (HandWeapon) item("Knife", ItemType.WEAPON);
        weapon.setCondition(10); weapon.setMinDamage(1); weapon.setMaxDamage(2);
        root.AddItem(weapon);
        InventoryItem ammo = item("Ammo", ItemType.NORMAL); root.AddItem(ammo);
        HandWeapon gun = (HandWeapon) item("Gun", ItemType.WEAPON);
        gun.setCondition(10); gun.setRanged(true); gun.setMagazineType(ammo.getFullType());
        person.getInventory().AddItem(gun);
        inspect(person, cabinet);
        check("food_query_preserves_source", SAONeeds.findFoodSourceNear(person, 5).startsWith("12:20:0:"));
        check("weapon_query_preserves_source", SAONeeds.findWeaponUpgradeNear(person, 5).startsWith("12:20:0:"));
        check("ammo_query_preserves_source", SAONeeds.findAmmoSourceNear(person, 5).startsWith("12:20:0:"));
        for (String kind : new String[] {"food", "weapon", "ammo"}) {
            check("adjacent_native_target_" + kind, "AT:11:20:0".equals(approach(person, kind, 12, 20, 0)));
        }
        check("nested_item_receipt_unchanged", SAONeeds.sourceItem(person) == food
            && SAONeeds.sourceContainer(person) == bag.getInventory());
        check("no_transfer_from_target_selection", food.getContainer() == bag.getInventory()
            && weapon.getContainer() == root && ammo.getContainer() == root);
        check("mismatched_coordinates_refused", "UNAVAILABLE".equals(approach(person, "food", 11, 20, 0)));
        check("mismatched_floor_refused", "UNAVAILABLE".equals(approach(person, "food", 12, 20, 1)));
        bag.getInventory().Remove(food);
        check("removed_item_refused", "UNAVAILABLE".equals(approach(person, "food", 12, 20, 0)));
        check("invalid_receipt_does_not_become_none", "UNAVAILABLE".equals(approach(person, "food", 12, 20, 0)));
        bag.getInventory().AddItem(food);
        root.Remove(bag); person.getInventory().AddItem(bag);
        check("moved_nested_holder_refused", "UNAVAILABLE".equals(approach(person, "food", 12, 20, 0)));
        person.getInventory().Remove(bag); root.AddItem(bag);
        cabinet.getSquare().getObjects().remove(cabinet);
        check("removed_world_holder_refused", "UNAVAILABLE".equals(approach(person, "weapon", 12, 20, 0)));
        cabinet.getSquare().getObjects().add(cabinet);
        root.setExplored(false);
        check("unknown_contents_not_admitted", "UNAVAILABLE".equals(approach(person, "ammo", 12, 20, 0)));
        check("query_does_not_discover_unknown_contents", SAONeeds.findAmmoSourceNear(person, 5).isEmpty());
        root.setExplored(true); inspect(person, cabinet); SAONeeds.findAmmoSourceNear(person, 5);
        for (int dy = -1; dy <= 1; dy++) for (int dx = -1; dx <= 1; dx++) {
            blocked(cell.getGridSquare(12 + dx, 20 + dy, 0), true);
        }
        check("no_free_target_refused", "UNAVAILABLE".equals(approach(person, "weapon", 12, 20, 0)));
        blocked(cell.getGridSquare(11, 20, 0), false);
        cabinet.getSquare().getProperties().set(IsoFlagType.collideW);
        check("wall_between_free_target_and_source_refused", "UNAVAILABLE".equals(approach(person, "weapon", 12, 20, 0)));
        cabinet.getSquare().getProperties().unset(IsoFlagType.collideW);
        check("actual_clear_side_restores_target", "AT:11:20:0".equals(approach(person, "weapon", 12, 20, 0)));
        person.setX(11.5f); person.setCurrent(cell.getGridSquare(11, 20, 0));
        check("selected_target_has_native_container_reach", SAONeeds.containerAccessibleNow(person, root));
        person.setX(10.5f); person.setCurrent(cell.getGridSquare(10, 20, 0));
        IsoObject sink = holder(cell, 14, 20, 0);
        FluidContainer fluids = fluid(sink);
        check("water_query_preserves_source", "14:20:0".equals(SAONeeds.findWaterSourceNear(person, 5)));
        check("water_avoids_occupied_source", "AT:14:19:0".equals(approach(person, "water", 14, 20, 0)));
        check("water_source_identity_retained", SAONeeds.waterSource(person) == sink && fluids.getAmount() == 2);
        fluids.Empty(); fluids.addFluid(Fluid.TaintedWater, 2);
        check("tainted_water_refused", "UNAVAILABLE".equals(approach(person, "water", 14, 20, 0)));
        fluids.Empty();
        check("dry_water_refused", "UNAVAILABLE".equals(approach(person, "water", 14, 20, 0)));
        fluids.addFluid(Fluid.Water, 2);
        sink.getSquare().getObjects().remove(sink);
        check("removed_water_object_refused", "UNAVAILABLE".equals(approach(person, "water", 14, 20, 0)));
        sink.getSquare().getObjects().add(sink);
        // The old source remains loaded but this object has moved to another tile.
        sink.setSquare(cell.getGridSquare(15, 20, 0));
        check("moved_water_source_refused", "UNAVAILABLE".equals(approach(person, "water", 14, 20, 0)));
        sink.setSquare(cell.getGridSquare(14, 20, 0));
        IsoGridSquare waterSquare = sink.getSquare();
        waterSquare.chunk.setSquare(14 % 8, 20 % 8, 0, null);
        check("unloaded_source_square_refused", "UNAVAILABLE".equals(approach(person, "water", 14, 20, 0)));
        waterSquare.chunk.setSquare(14 % 8, 20 % 8, 0, waterSquare);
        root.Remove(weapon);
        IsoObject upper = holder(cell, 12, 20, 1); upper.getContainer().AddItem(weapon);
        inspect(person, upper);
        check("upstairs_source_keeps_floor", SAONeeds.findWeaponUpgradeNear(person, 5).startsWith("12:20:1:"));
        check("upstairs_target_keeps_floor", "AT:11:20:1".equals(approach(person, "weapon", 12, 20, 1)));
        vehicle(cell, person, root, bag);
        SAONeeds.resetRuntimeForWorld();
        check("reset_discards_receipt", "NONE".equals(approach(person, "weapon", 12, 20, 1)));
        System.out.println("PASS resource approach checks=" + checks);
    }
}
