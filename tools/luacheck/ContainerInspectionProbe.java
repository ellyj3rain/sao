import com.sao.engine.SAOWorldSources;
import java.lang.reflect.Method;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.LinkedHashMap;
import java.util.Map;
import zombie.characters.IsoPlayer;
import zombie.inventory.ItemContainer;
import zombie.inventory.ItemPickerJava;
import zombie.iso.IsoCell;
import zombie.iso.IsoGridSquare;
import zombie.iso.IsoObject;
import zombie.iso.SpriteDetails.IsoFlagType;
import zombie.iso.sprite.IsoSprite;

/** Controlled native geometry and distribution; calls the production inspector. */
public class ContainerInspectionProbe {
    private static int cases;
    private static void check(String name, boolean passed) {
        if (!passed) {
            try { System.out.println(Files.readString(Path.of(System.getProperty("user.home"),
                "Zomboid", "SAOAgent.log"))); } catch (Exception absent) { }
            throw new AssertionError(name);
        }
        cases++; System.out.println("CASE " + name);
    }
    private static Object fixture(String name, Class<?>[] types, Object... args) throws Exception {
        Method method = MovementCrossingProbe.class.getDeclaredMethod(name, types);
        method.setAccessible(true); return method.invoke(null, args);
    }
    private static void position(IsoPlayer shell, IsoCell cell, float x, float y) {
        shell.setX(x); shell.setY(y); shell.setZ(0);
        shell.setCurrent(cell.getGridSquare((int)x, (int)y, 0));
    }
    private static IsoObject holder(IsoCell cell, int x, int y) {
        IsoGridSquare square = cell.getGridSquare(x, y, 0);
        IsoObject object = new IsoObject(cell); object.setSquare(square);
        object.setSprite(new IsoSprite());
        ItemContainer container = new ItemContainer("counter", square, object);
        object.setContainer(container); container.setExplored(false);
        square.getObjects().add(object); return object;
    }
    private static Map<String,String> first(String text) {
        Map<String,String> result = new LinkedHashMap<>();
        for (String line : text.split("\n")) if (line.startsWith("C|")) {
            for (String part : line.substring(2).split("\\|")) {
                int at = part.indexOf('='); result.put(part.substring(0, at), part.substring(at + 1));
            }
            return result;
        }
        return result;
    }
    private static String inspect(IsoPlayer shell, Map<String,String> row) {
        return SAOWorldSources.inspectContainer(shell, row.get("id"), row.get("fp"),
            Integer.parseInt(row.get("sx")), Integer.parseInt(row.get("sy")),
            Integer.parseInt(row.get("sz")));
    }
    private static Map<String,String> at(String text, int x) {
        for (String line : text.split("\n")) if (line.startsWith("C|")) {
            Map<String,String> row = first(line);
            if (Integer.toString(x).equals(row.get("sx"))) return row;
        }
        return Map.of();
    }
    public static void main(String[] args) throws Exception {
        IsoCell cell = (IsoCell)fixture("boot", new Class<?>[0]);
        var regionRoot = zombie.iso.areas.isoregion.IsoRegions.class.getDeclaredField("dataRoot");
        regionRoot.setAccessible(true);
        regionRoot.set(null, new zombie.iso.areas.isoregion.data.DataRoot());
        IsoPlayer actor = (IsoPlayer)fixture("person", new Class<?>[]{IsoCell.class}, cell);
        IsoPlayer other = (IsoPlayer)fixture("person", new Class<?>[]{IsoCell.class}, cell);
        actor.getModData().rawset("SAOPersonId", "inspector-a");
        other.getModData().rawset("SAOPersonId", "inspector-b");
        var actorMemory=(se.krka.kahlua.vm.KahluaTable)SAOWorldSources.inspectionMemory(actor);
        actorMemory.rawset("marker", "actor-only");
        check("native_inspection_memory_isolated", SAOWorldSources.inspectionMemory(actor)==actorMemory
            && ((se.krka.kahlua.vm.KahluaTable)SAOWorldSources.inspectionMemory(other)).rawget("marker")==null);
        actor.setForwardDirection(1, 0); other.setForwardDirection(1, 0);
        // A real engine distribution with no rollable items. The event callback
        // counts actual native fill invocations; it does not replace ItemPicker.
        var room = new ItemPickerJava.ItemPickerRoom();
        var distribution = new ItemPickerJava.ItemPickerContainer();
        distribution.items = new ItemPickerJava.ItemPickerItem[0];
        distribution.rolls = 0;
        room.containers.put("counter", distribution);
        ItemPickerJava.rooms.put("all", room);
        zombie.Lua.LuaManager.env.rawset("fillCount", 0.0);
        var thread = new se.krka.kahlua.vm.KahluaThread(zombie.Lua.LuaManager.platform,
            zombie.Lua.LuaManager.env);
        thread.debugOwnerThread = Thread.currentThread();
        zombie.Lua.LuaManager.thread = thread;
        var callback = se.krka.kahlua.luaj.compiler.LuaCompiler.loadstring(
            "Events.OnFillContainer.Add(function(room, kind, container) fillCount=fillCount+1 end)",
            "fill-counter", zombie.Lua.LuaManager.env);
        Object[] callbackResult = thread.pcall(callback, new Object[0]);
        check("native_fill_listener", Boolean.TRUE.equals(callbackResult[0]));
        IsoObject cabinet = holder(cell, 11, 20);
        IsoObject decoy = holder(cell, 13, 20);
        decoy.getContainer().setExplored(true);
        ItemContainer container = cabinet.getContainer();
        String candidates = SAOWorldSources.inspectionCandidates(actor, 12);
        Map<String,String> offered = first(candidates);
        if (offered.isEmpty()) {
            System.out.println("CANDIDATES " + candidates);
            Path logs = Path.of(System.getProperty("user.home"), "Zomboid");
            if (Files.isDirectory(logs)) try (var files = Files.list(logs)) {
                for (Path log : files.filter(p -> p.getFileName().toString().startsWith("SAO")).toList()) {
                    if (Files.isRegularFile(log)) System.out.println(Files.readString(log));
                }
            }
            Method live = SAOWorldSources.class.getDeclaredMethod("inspectionActor", IsoPlayer.class);
            live.setAccessible(true); System.out.println("LIVE " + live.invoke(null,actor));
            Method approach = SAOWorldSources.class.getDeclaredMethod("interactionSquare", IsoPlayer.class, IsoGridSquare.class);
            approach.setAccessible(true); System.out.println("APPROACH " + approach.invoke(null,actor,cabinet.getSquare()));
            Method id = SAOWorldSources.class.getDeclaredMethod("privateContainerId", IsoObject.class,int.class);
            id.setAccessible(true); System.out.println("ID " + id.invoke(null,cabinet,0));
            System.out.println("CONTAINER parent=" + (container.getParent()==cabinet)
                + " square=" + (container.getSourceGrid()==cabinet.getSquare())
                + " root=" + (container.getOutermostContainer()==container)
                + " count=" + cabinet.getContainerCount() + " dead=" + actor.isDead()
                + " asleep=" + actor.isAsleep() + " free=" + cabinet.getSquare().isFree(false)
                + " face=" + actor.getForwardDirectionX() + "," + actor.getForwardDirectionY());
            Method visible = com.sao.engine.SAOPerceptionScanner.class.getDeclaredMethod(
                "canSeeWorldSquareNow", zombie.characters.IsoGameCharacter.class, IsoGridSquare.class, float.class);
            visible.setAccessible(true);
            System.out.println("VISIBLE " + visible.invoke(null,actor,cabinet.getSquare(),12f));
        }
        check("metadata_only_unknown", !offered.isEmpty() && !container.isExplored()
            && container.getItems().isEmpty() && !candidates.contains("q:")
            && !candidates.contains("|rev=") && !candidates.contains("|type="));
        check("foreign_actor_refused", inspect(other, offered).equals("NOT_OFFERED")
            && !container.isExplored());
        position(actor, cell, 5.5f, 20.5f);
        check("unreachable_refused", inspect(actor, offered).equals("ACCESS_REFUSED")
            && !container.isExplored());
        position(actor, cell, 10.5f, 20.5f);
        String fingerprint = offered.get("fp"); offered.put("fp", "0".repeat(64));
        check("wrong_fingerprint_refused", inspect(actor, offered).equals("NOT_OFFERED")
            && !container.isExplored()); offered.put("fp", fingerprint);
        cabinet.getSquare().getObjects().remove(cabinet);
        IsoObject replacement = holder(cell, 11, 20);
        replacement.getModData().rawset("SAOWorldSourceId", cabinet.getModData().rawget("SAOWorldSourceId"));
        check("cloned_identity_refused", inspect(actor, offered).equals("SOURCE_CHANGED")
            && !replacement.getContainer().isExplored() && !container.isExplored());
        replacement.getSquare().getObjects().remove(replacement);
        cabinet.getSquare().getObjects().add(cabinet);
        zombie.network.GameClient.client = true;
        check("client_authority_refused", inspect(actor, offered).equals("SERVER_AUTHORITY_REQUIRED")
            && !container.isExplored()); zombie.network.GameClient.client = false;
        String snapshot = inspect(actor, offered);
        if (!snapshot.startsWith("I|source=")) System.out.println("INSPECTION " + snapshot);
        check("native_empty_inspection", snapshot.startsWith("I|source=")
            && snapshot.contains("|state=spent|") && container.isExplored());
        double firstFill = ((Number)zombie.Lua.LuaManager.env.rawget("fillCount")).doubleValue();
        check("native_fill_once", firstFill == 1);
        check("repeat_inspection_no_roll", inspect(actor, offered).startsWith("I|source=")
            && ((Number)zombie.Lua.LuaManager.env.rawget("fillCount")).doubleValue() == firstFill);
        Map<String,String> second = first(SAOWorldSources.inspectionCandidates(other, 12));
        check("second_actor_own_inspection", !second.isEmpty() && inspect(other, second).startsWith("I|source=")
            && ((Number)zombie.Lua.LuaManager.env.rawget("fillCount")).doubleValue() == firstFill);
        SAOWorldSources.resetRuntimeForWorld();
        check("world_reset_drops_offers", inspect(actor, offered).equals("NOT_OFFERED"));
        check("world_reset_drops_memory", SAOWorldSources.inspectionMemory(actor)!=actorMemory);
        // Native opaque obstacle plus same sight policy as personal perception.
        cabinet.getSquare().getProperties().set(IsoFlagType.collideW);
        cabinet.getSquare().getProperties().set(IsoFlagType.cutW);
        cabinet.getSquare().ReCalculateVisionBlocked(cell.getGridSquare(10,20,0));
        check("opaque_holder_not_offered", !SAOWorldSources.inspectionCandidates(actor, 12)
            .contains("C|id=" + offered.get("id") + "|"));
        cabinet.getSquare().getProperties().unset(IsoFlagType.collideW);
        cabinet.getSquare().getProperties().unset(IsoFlagType.cutW);
        cabinet.getSquare().ReCalculateVisionBlocked(cell.getGridSquare(10,20,0));
        // Reuse the existing real Item/WorldDictionary fixture, then let the
        // installed picker itself instantiate the item from a controlled roll.
        var dictionary = PrivateInventoryProbe.class.getDeclaredField("DICTIONARY");
        dictionary.setAccessible(true);
        var dictionaryOwner = zombie.world.WorldDictionary.class.getDeclaredField("data");
        dictionaryOwner.setAccessible(true); dictionaryOwner.set(null,dictionary.get(null));
        var module = new zombie.scripting.objects.ScriptModule(); module.name = "C71";
        zombie.scripting.ScriptManager.instance.moduleMap.put("C71",module);
        var itemFixture = Class.forName("PrivateInventoryProbe$FixtureItem").getDeclaredConstructor(
            zombie.scripting.objects.ScriptModule.class, String.class,
            zombie.scripting.objects.ItemType.class, short.class);
        itemFixture.setAccessible(true);
        Object foodFixture=itemFixture.newInstance(module,"InspectionFood",zombie.scripting.objects.ItemType.FOOD,(short)74);
        var itemDefinition=foodFixture.getClass().getDeclaredField("definition"); itemDefinition.setAccessible(true);
        var foodDefinition=(zombie.scripting.objects.Item)itemDefinition.get(foodFixture);
        foodDefinition.setHungerChange(-10);
        var roll = new ItemPickerJava.ItemPickerItem(); roll.itemName="C71.InspectionFood"; roll.chance=100000;
        distribution.items = new ItemPickerJava.ItemPickerItem[]{roll};
        distribution.rolls=1; distribution.ignoreZombieDensity=true; distribution.noAutoAge=true;
        ItemPickerJava.InitSandboxLootSettings();
        var stashes = zombie.core.stash.StashSystem.class.getDeclaredField("possibleStashes");
        stashes.setAccessible(true); stashes.set(null,new java.util.ArrayList<>());
        IsoObject stocked = holder(cell,14,20);
        position(actor,cell,13.5f,20.5f);
        String stockCandidates = SAOWorldSources.inspectionCandidates(actor,12);
        Map<String,String> stockOffer = at(stockCandidates,14);
        check("distribution_not_rolled_during_offer", !stockOffer.isEmpty()
            && stocked.getContainer().getItems().isEmpty() && !stocked.getContainer().isExplored()
            && !stockCandidates.contains("InspectionFood"));
        String stockSnapshot = inspect(actor,stockOffer);
        check("native_picker_generates_exact_contents", stockSnapshot.startsWith("I|source=")
            && stockSnapshot.contains("C71.InspectionFood") && !stocked.getContainer().getItems().isEmpty());
        int itemCount = stocked.getContainer().getItems().size();
        check("generated_items_not_duplicated", inspect(actor,stockOffer).startsWith("I|source=")
            && stocked.getContainer().getItems().size()==itemCount);
        check("own_inspection_admits_direct_food", com.sao.engine.SAONeeds.findFoodSourceNear(actor,12).startsWith("14:20:0:"));
        String revision=null;
        for (String line : stockSnapshot.split("\n")) if (line.startsWith("S|id="+stockOffer.get("id")+"|")) {
            for (String part : line.split("\\|")) if (part.startsWith("rev=")) revision=part.substring(4);
        }
        boolean unsupportedIterator = false;
        try { stocked.getSquare().getObjects().iterator(); }
        catch (UnsupportedOperationException expected) { unsupportedIterator = true; }
        check("native_square_objects_require_supported_traversal", unsupportedIterator);
        var selectedFood = stocked.getContainer().getItems().get(0);
        String transfer = SAOWorldSources.transferOffer(actor, selectedFood,
            stocked.getContainer(), "acquire");
        check("inspected_native_holder_offers_exact_transfer", transfer.startsWith("T|operation=acquire|source="
            + stockOffer.get("id") + "|") && transfer.contains("|id=" + selectedFood.getID() + "|"));
        check("transfer_offer_does_not_move_items", stocked.getContainer().getItems().size() == itemCount
            && selectedFood.getContainer() == stocked.getContainer()
            && !actor.getInventory().contains(selectedFood));
        check("inspected_native_action_target_resolves", SAOWorldSources.actionTarget(actor,
            stockOffer.get("id"), stockOffer.get("fp"), revision, selectedFood.getID(),
            selectedFood.getFullType(), 14,20,0).startsWith("READY:"));
        check("inspected_native_action_binds_exact_item", SAOWorldSources.bindAction(actor,
            stockOffer.get("id"), stockOffer.get("fp"), revision, selectedFood.getID(),
            selectedFood.getFullType(), 14,20,0).equals("BOUND:14:20:0")
            && SAOWorldSources.actionItem(actor) == selectedFood);
        SAOWorldSources.clearAction(actor);
        check("native_action_stale_fingerprint_refused", SAOWorldSources.actionTarget(actor,
            stockOffer.get("id"), "0".repeat(64), revision, selectedFood.getID(),
            selectedFood.getFullType(), 14,20,0).equals("FINGERPRINT_CHANGED"));
        check("native_action_stale_revision_refused", SAOWorldSources.actionTarget(actor,
            stockOffer.get("id"), stockOffer.get("fp"), "stale", selectedFood.getID(),
            selectedFood.getFullType(), 14,20,0).equals("REVISION_CHANGED"));
        check("native_action_malformed_id_refused", SAOWorldSources.actionTarget(actor,
            stockOffer.get("id") + ":extra", stockOffer.get("fp"), revision, selectedFood.getID(),
            selectedFood.getFullType(), 14,20,0).equals("BAD_SOURCE_ID"));
        position(actor,cell,10.5f,20.5f);
        check("native_transfer_requires_actual_reach", SAOWorldSources.transferOffer(actor,
            selectedFood, stocked.getContainer(), "acquire").isEmpty());
        position(actor,cell,13.5f,20.5f);
        var barrier=cell.getGridSquare(12,20,0);
        barrier.getProperties().set(IsoFlagType.collideW); barrier.getProperties().set(IsoFlagType.cutW);
        barrier.ReCalculateVisionBlocked(cell.getGridSquare(11,20,0));
        check("other_behind_wall_cannot_read_stock", com.sao.engine.SAONeeds.findFoodSourceNear(other,12).isEmpty());
        barrier.getProperties().unset(IsoFlagType.collideW); barrier.getProperties().unset(IsoFlagType.cutW);
        barrier.ReCalculateVisionBlocked(cell.getGridSquare(11,20,0));
        position(other,cell,13.5f,20.5f);
        check("reach_does_not_mean_inspected", com.sao.engine.SAONeeds.findFoodSourceNear(other,12).isEmpty());
        var otherStock=at(SAOWorldSources.inspectionCandidates(other,12),14);
        check("other_stock_requires_own_inspection", inspect(other,otherStock).startsWith("I|source=")
            && com.sao.engine.SAONeeds.findFoodSourceNear(other,12).startsWith("14:20:0:")
            && stocked.getContainer().getItems().size()==itemCount);
        // Restore the exact existing Perception sourceFact wire shape, with a
        // numeric place key. The separate Kahlua cases execute its real writer.
        var platform=zombie.Lua.LuaManager.platform;
        var sao=platform.newTable(); var perception=platform.newTable(); var beliefs=platform.newTable();
        var mind=platform.newTable(); var known=platform.newTable(); var place=platform.newTable();
        var facts=platform.newTable(); var fact=platform.newTable();
        fact.rawset("fingerprint",stockOffer.get("fp")); fact.rawset("revision",revision);
        fact.rawset("explored",Boolean.TRUE); fact.rawset("state","available");
        facts.rawset(stockOffer.get("id"),fact); place.rawset("sourceFacts",facts); known.rawset(42.0,place);
        mind.rawset("known",known); beliefs.rawset("inspector-a",mind);
        perception.rawset("beliefs",beliefs); sao.rawset("Perception",perception);
        zombie.Lua.LuaManager.env.rawset("SAO",sao);
        SAOWorldSources.resetRuntimeForWorld();
        check("unchanged_private_memory_survives_reset", com.sao.engine.SAONeeds.findFoodSourceNear(actor,12).startsWith("14:20:0:"));
        var oldPlace=platform.newTable(); var oldFacts=platform.newTable(); var oldFact=platform.newTable();
        oldFact.rawset("fingerprint",stockOffer.get("fp")); oldFact.rawset("revision","older");
        oldFact.rawset("explored",Boolean.TRUE); oldFact.rawset("state","available");
        oldFacts.rawset(stockOffer.get("id"),oldFact); oldPlace.rawset("sourceFacts",oldFacts);
        var aliases=platform.newTable(); aliases.rawset("42",oldPlace); aliases.rawset(42.0,place);
        mind.rawset("known",aliases);
        check("numeric_string_alias_keeps_matching_private_fact", com.sao.engine.SAONeeds.findFoodSourceNear(actor,12).startsWith("14:20:0:"));
        check("memory_is_not_shared", com.sao.engine.SAONeeds.findFoodSourceNear(other,12).isEmpty());
        var laterFood=foodDefinition.InstanceItem(null,false); stocked.getContainer().AddItem(laterFood);
        check("stale_private_revision_cannot_reveal_added_stock", com.sao.engine.SAONeeds.findFoodSourceNear(actor,12).isEmpty());
        var locked = new zombie.iso.objects.IsoThumpable(cell);
        IsoGridSquare lockedSquare=cell.getGridSquare(16,20,0);
        locked.setSquare(lockedSquare); locked.setSprite(new IsoSprite());
        locked.setContainer(new ItemContainer("counter",lockedSquare,locked));
        lockedSquare.getObjects().add(locked); locked.setLockedByCode(123);
        position(actor,cell,15.5f,20.5f);
        check("native_locked_holder_not_offered", locked.isLockedToCharacter(actor)
            && at(SAOWorldSources.inspectionCandidates(actor,12),16).isEmpty()
            && !locked.getContainer().isExplored());
        locked.setLockedByCode(0);
        Map<String,String> lockOffer=at(SAOWorldSources.inspectionCandidates(actor,12),16);
        check("native_unlocked_holder_offered", !lockOffer.isEmpty());
        locked.setLockedByCode(123);
        check("lock_rechecked_at_inspection", inspect(actor,lockOffer).equals("ACCESS_REFUSED")
            && !locked.getContainer().isExplored());
        if (args.length > 0) {
            Files.writeString(Path.of(args[0], "candidates.txt"), candidates);
            Files.writeString(Path.of(args[0], "snapshot.txt"), snapshot);
        }
        System.out.println("PASS container inspection: " + cases + " actual native cases");
        System.exit(0);
    }
}
